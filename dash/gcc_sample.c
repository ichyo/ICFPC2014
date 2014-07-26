main(world, unknown) {
    return (init(0, 0, 0), step);
}

init(a, b, c) {
    return (1, (0, 0));
}

step(state, world) {
    state = task(car(state), car(cdr(state)), cdr(cdr(state)));
    return (state, car(state));
}

task(dir, cnt, len) {
    cnt = cnt + 1;
    if (cnt == len) {
        cnt = 0;
        len = len + 1;
        dir = dir + 1;
    }
    if (dir == 4) dir = 0;
    return (dir, (cnt, len));
}
