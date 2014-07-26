#include "log.h"
ofstream flog("log.txt");
void logging(const char *level, const char *file, const int line, const char *format, ...) {
    va_list argp;
    char s[256];
    string out;
    sprintf(s, "%s%s(%d): ", level, file, line);
    out += string(s);
    va_start(argp, format);
    vsprintf(s, format, argp);
    out += string(s);
    va_end(argp);
    flog << out << endl;
}
