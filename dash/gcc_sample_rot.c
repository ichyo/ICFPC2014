main(world, unknown) {
    return (0, step);
}

step(state, world) {
    state = state + 1;
    if (state == 4) state = 0;
    return (state, state);
}

