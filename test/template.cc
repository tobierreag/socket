#include <stdio.h>
#include <iostream>
#include "common.hh"
#include "../test.h"

int main () {

   std::cout << std::string(greeting) << std::endl;

   /* const std::string test="hello world";
   std::ostringstream result;
   std::string name="greeting";
   result << "constexpr char " << name << "[] = { 0x";
   result << std::setw(2) << std::setfill('0') << std::hex;
   std::copy(test.begin(), test.end(), std::ostream_iterator<unsigned int>(result, ", 0x"));
   result << "3b };";

   Operator::writeFile("test.h", result.str()); */

  /* char* name = "1.1.1.1";
  char* port = "8080";
  auto s1 = Operator::encodeURIComponent(Operator::format(R"({
    "data": {
      "status": "READY",
      "ip": "$C",
      "port": "$C"
    }
  })", name, port));

  std::string a = "Allice";
  std::string b = "Bob";

  auto s2 = Operator::format(
    "Hello, $S."
    "There are $i copies of $c for $S.",
    a, 100, 'x', b);

  std::cout << s1 << std::endl;
  std::cout << s2 << std::endl;

  std::string x("8080");
  char* p = (char* const) x.c_str();
  std::cout << p << std::endl; */
}