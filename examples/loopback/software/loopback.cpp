
#include <fcntl.h>
#include <unistd.h>

#include <sys/poll.h>

#include <cstdint>
#include <vector>
#include <cstdio>

#include <stdlib.h>
#include <sys/ioctl.h>
#include "../../../software/linux_driver/mmio_ioctl.h"

using std::uint8_t;
using std::uint32_t;
using std::vector;

int main() {


	// Open channel file devices.
	//int rx = open("/dev/fpga_1_rx_1", O_WRONLY);
	int rx = open("/dev/virtex7_1_rx_1", O_WRONLY);
	printf("Opening RX Channel\n");
	if(rx == -1) {
		perror("Failed to open rx channel\n");
		return 1;
	}

	printf("Opening TX Channel\n");
	//int tx = open("/dev/fpga_1_tx_2", O_RDONLY);
	int tx = open("/dev/virtex7_1_tx_2", O_RDONLY);
	if(tx == -1) {
		perror("Failed to open tx channel\n");
		return 1;
	}

	// Alloc 128MB buffers for loopback.
	constexpr size_t bufsize = 512 * 1024 * 1024; //2048ULL *  1024 * 1024;
	vector<uint8_t> heap_buffer_write, heap_buffer_read;
	heap_buffer_write.resize(bufsize, 0);
	heap_buffer_read.resize(bufsize, 1);

	// Reset endpoint to align sequence.
	int ep_fd = open("/dev/virtex7_1", O_RDWR);
	vcl_register rst = {0, 7, 1};
	ioctl(ep_fd, VCL_MMIO_IOCTL_WRREG, &rst);
	

	uint64_t v = 0;
	for(size_t index = 0; index < heap_buffer_write.size(); index += 16) {
		uint64_t *wr_ptr = reinterpret_cast<uint64_t*>(&heap_buffer_write.data()[index]);
		*wr_ptr = v++;
	}

	struct pollfd polls[2];
	size_t bytes_written = 0, bytes_read = 0;

	while(bytes_written < bufsize || bytes_read < bufsize) {
		size_t requests = 0;
		if(bytes_written < bufsize) {
			polls[requests].fd = rx;
			polls[requests].events = POLLOUT;
			requests++;
		}
		if(bytes_read < bufsize) {
			polls[requests].fd = tx;
			polls[requests].events = POLLIN;
			requests++;
		}

		int ret = poll(polls, requests, 1000);
		if(!ret) {
			perror("Poll timed out.\n");
			break;
		}
		bool failed = false;
		for(size_t i = 0; i < requests; ++i) {
			if(polls[i].revents & POLLOUT && bytes_written < bufsize) {
				int ret = write(polls[i].fd, &heap_buffer_write[bytes_written], bufsize - bytes_written);
				if(ret < 0) {
					perror("Failed to write channel\n");
				} else {
					bytes_written += ret;
					printf("%lu/%lu bytes written (%d byte chunk)\n", bytes_written, bufsize, ret);
				}
			}

			if(polls[i].revents & POLLIN && bytes_read < bufsize) {
				int ret = read(polls[i].fd, &heap_buffer_read[bytes_read], bufsize - bytes_read);
				if(ret < 0) {
					perror("Failed to read channel\n");
					failed = true;
					break;
				} else {
					bytes_read += ret;
					printf("%lu/%lu bytes read (%d byte chunk)\n", bytes_read, bufsize, ret);
				}
			}
		}
		if(failed) break;
	}

	for(size_t index = 0; index < heap_buffer_read.size(); index += 16) {
		uint64_t *rd_buf_ptr, *wr_buf_ptr;
		rd_buf_ptr = reinterpret_cast<uint64_t*>(&heap_buffer_read.data()[index]);
		wr_buf_ptr = reinterpret_cast<uint64_t*>(&heap_buffer_write.data()[index]);

		if(*rd_buf_ptr != *wr_buf_ptr) {
			fprintf(stderr, "Found first error at index %lu. Got %lu, expected %lu\n", index, *rd_buf_ptr, *wr_buf_ptr);
			FILE* outfile;
			outfile = fopen("./output.log", "w+");
			if(!outfile) return 1;
			fprintf(outfile, "Return values starting with index %lu:\n", index);
			int cursor = ((int)index - 10*16) < 0 ? 0 : (index - 10*16);

			for(; (size_t)cursor < heap_buffer_read.size(); cursor += 16) {
				rd_buf_ptr = reinterpret_cast<uint64_t*>(&heap_buffer_read.data()[cursor]);
				fprintf(outfile, "%lu ", *rd_buf_ptr);
			}
			fprintf(outfile, "\n");
			fclose(outfile);
			break;
		}
	}

	close(rx);
	close(tx);
}
