
CXX := -c++
CXXFLAGS := -std=c++11 -Wall -Werror -Wextra -pedantic-errors

all: loopback

loopback: loopback.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

clean:
	rm -rvf loopback
