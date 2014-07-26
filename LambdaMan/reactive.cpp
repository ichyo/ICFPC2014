#include "reactive.h"
#include "log.h"
using namespace std;

Reactive::Reactive() : started(false) {
    debug("Reactive(%08x) constructer : started %d", this, started);
}
Reactive::Reactive(string command) : started(false) {
    debug("Reactive(%08x) constructer : started %d command %s", this, started, command.c_str());
    Start(command);
}

Reactive::~Reactive(){
    debug("Reactive(%08x) destructer : started %d", this, started);
    reactive_end();
}

string Reactive::Read() {
    debug("Reactive(%08x) Read : Start", this);
    assert(started);
    return reactive_read();
}

void Reactive::Write(string s) {
    debug("Reactive(%08x) Write : %s", this, s.c_str());
    assert(started);
    reactive_write(s);
    debug("Reactive(%08x) Write End", this);
}

int Reactive::Start(std::string command) {
    started = true;
    debug("Reactive(%08x) start : command %s", this, command.c_str());
    int pipe_c2p[2], pipe_p2c[2];

    signal(SIGPIPE, SIG_IGN);
    if (pipe(pipe_c2p) < 0 || pipe(pipe_p2c) < 0) {
        fprintf(stderr, "pipe: failed to open pipes\n");
        return 1;
    }
    if ((__reactive_pid = fork()) < 0) {
        fprintf(stderr, "fork: failed to fork\n");
        return 1;
    }
    if (__reactive_pid == 0) {
        close(pipe_p2c[1]); close(pipe_c2p[0]);
        dup2(pipe_p2c[0], 0); dup2(pipe_c2p[1], 1);
        close(pipe_p2c[0]); close(pipe_c2p[1]);
        exit(system(command.c_str()) ? 1 : 0);
    }
    close(pipe_p2c[0]); close(pipe_c2p[1]);
    __reactive_input = pipe_p2c[1];
    __reactive_output = pipe_c2p[0];
    debug("Reactive start : end", command.c_str());
    return 0;
}
void Reactive::reactive_end() {
    int status;
    close(__reactive_input);
    waitpid(__reactive_pid, &status, WUNTRACED);
}

void Reactive::reactive_write(std::string buf) {
    write(__reactive_input, buf.c_str(), buf.size());
}

std::string Reactive::reactive_read(int max_len) {
    static char buf[1024]; static int len = 0; std::string result;
    while (result.size() < max_len) {
        if (!len) {
            len = read(__reactive_output, buf,
                    std::min(1000, (int)(max_len - result.size())));
            if (!len) return result;
        }
        char *pos = (char *)memchr(buf, '\n', len);
        if (pos) {
            result += std::string(buf, pos - buf + 1);
            memmove(buf, pos + 1, len - (pos + 1 - buf));
            len -= pos - buf + 1;
            return result;
        } else {
            result += std::string(buf, len);
            len = 0;
        }
    }
    return result;
}
