#include <algorithm>
#include <string>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>
#include <signal.h>
#include <bits/stdc++.h>
using namespace std;
struct Reactive{
    pid_t __reactive_pid;
    int __reactive_input, __reactive_output;
    bool started;

    Reactive();
    Reactive(string command);
    ~Reactive();
    string Read();
    void Write(string s);
    int Start(string command);

    void reactive_end();

    void reactive_write(std::string buf);

    std::string reactive_read(int max_len=100000);
private:
    // コピー禁止
    //Reactive(const Reactive&);              
    //Reactive& operator=(const Reactive&); 
};

