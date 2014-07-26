#include <bits/stdc++.h>
#define REP(i,n) for(int i=0; i<(int)(n); ++i)
using namespace std;
ofstream flog( "log.txt");
void sleep(int ms) {
    std::chrono::milliseconds dura( ms );
    std::this_thread::sleep_for( dura );
}
void logging(const char *level, const char *file, const int line, const char *format, ...)
{
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
#define debug(...) logging("[DEBUG]", __FILE__, __LINE__, __VA_ARGS__);

int dx[4] = {0, 1, 0, -1};
int dy[4] = {-1, 0, 1, 0};
enum BTYPE{
    EMPTY,
    WALL,
    PILL,
    P_PILL,
    FRUIT,
    BTYPE_LAST
};
enum DIRECTION{
    UP = 0,
    RIGHT = 1,
    DOWN = 2,
    LEFT = 3
};
class Field{
    static const int MAX_L = 256;
    static const int FIRST_FRUIT_AP = 127 * 200;
    static const int FIRST_FRUIT_DP = 127 * 280;
    static const int SECOND_FRUIT_AP = 127 * 400;
    static const int SECOND_FRUIT_DP = 127 * 480;
    int W, H;
    BTYPE type[MAX_L][MAX_L];
    int cnt[BTYPE_LAST];
    pair<int, int> fruit_coord;
public:
    Field(vector<string> init) :
        W(init[0].size()),
        H(init.size())
    {
        assert(W <= MAX_L && H <= MAX_L);
        memset(cnt, 0, sizeof(cnt));
        for(int y = 0; y < H; y++) {
            for(int x = 0; x < W; x++) {
                if(init[y][x] == ' ') {
                    type[y][x] = EMPTY;
                } else if(init[y][x] == '#') {
                    type[y][x] = WALL;
                } else if(init[y][x] == '.') {
                    type[y][x] = PILL;
                } else if(init[y][x] == 'o') {
                    type[y][x] = P_PILL;
                } else if(init[y][x] == '%') {
                    type[y][x] = EMPTY;
                    fruit_coord = {x, y};
                } else if(init[y][x] == '\\') {
                    type[y][x] = EMPTY;
                } else if(init[y][x] == '=') {
                    type[y][x] = EMPTY;
                } else {
                    assert(false);
                }
                cnt[ type[y][x] ] ++;
            }
        }
    }

    int width() const {
        return W;
    }

    int height() const {
        return H;
    }

    int get(int x, int y) const  {
        return type[y][x];
    }

    int get(pair<int, int> coord) const  {
        return type[coord.second][coord.first];
    }

    int count(BTYPE b) const {
        return cnt[b];
    }

    void action(int tick) {
        // 移動と同時にフルーツは取れないらしい(参考 FAQ)ので1を足している(正しい?)
        if(tick == FIRST_FRUIT_AP + 1 || tick == SECOND_FRUIT_AP + 1) {
            set(fruit_coord, FRUIT);
        }
        if(tick == FIRST_FRUIT_DP || tick == SECOND_FRUIT_DP) {
            set(fruit_coord, EMPTY);
        }
    }

    void set(int x, int y, BTYPE b) {
        cnt[ type[y][x] ]--;
        cnt[ b ] ++;
        type[y][x] = b;
    }

    void set(pair<int, int> coord, BTYPE b) {
        set(coord.first, coord.second, b);
    }

    bool valid(int x, int y) const {
        return 0 <= x && x < W && 0 <= y && y < H && type[y][x] != WALL;
    }

    vector<string> to_string() {
        vector<string> res;
        for(int y = 0; y < H; y++) {
            string row;
            for(int x = 0; x < W; x++) {
                if(type[y][x] == EMPTY) {
                    row += " ";
                } else if(type[y][x] == WALL) {
                    row += "#";
                } else if(type[y][x] == PILL) {
                    row += ".";
                } else if(type[y][x] == P_PILL) {
                    row += "o";
                } else if(type[y][x] == FRUIT) {
                    row += "%";
                } else {
                    assert(false);
                }
            }
            res.push_back(row);
        }
        return res;
    }
};
class AI{
    static const int TICK_PER_MOVE = 127;
    static const int TICK_PER_MOVE_EAT = 137;
    static const int FRIGHT_DURATION = 127 * 20;
    int cx, cy;
    int init_x, init_y;
    int next_tick;
    int last_power_pill;
    bool fright_mode;
    int eat_cnt;
    int life_cnt;
    int last_dir;
public:
    AI() {}
    AI(int x, int y) :
        cx(x),
        cy(y),
        init_x(x),
        init_y(y),
        next_tick(TICK_PER_MOVE),
        last_power_pill(-1),
        fright_mode(false),
        eat_cnt(0),
        life_cnt(3),
        last_dir(DOWN)
    {}

    int think() {
        return rand() % 4;
    }

    void move(const Field& field, int tick) {
        if(tick == next_tick) {
            int r = think();
            int nx = cx + dx[r];
            int ny = cy + dy[r];

            debug("move tick = %d r = %d nx = %d ny = %d", tick, r, nx, ny);

            if(field.valid(nx, ny)) {
                cx = nx;
                cy = ny;
                last_dir = r;
            } 

            if(field.get(cx, cy) == PILL) {
                next_tick += TICK_PER_MOVE_EAT;
            }else {
                next_tick += TICK_PER_MOVE;
            }

            last_dir = r;
        }
    }

    pair<int, int> coord() {
        return {cx, cy};
    }

    bool is_fright() {
        return fright_mode;
    }

    void set_fright(int tick) {
        fright_mode = true;
        last_power_pill = tick;
    }

    void action(int tick) {
        if(tick == last_power_pill + FRIGHT_DURATION) {
            // fright モード 終わりの処理
            fright_mode = false;
            eat_cnt = 0;
        }
    }

    void eat() {
        eat_cnt ++;
    }

    int eat_count() {
        return eat_cnt;
    }

    int lives() {
        return life_cnt;
    }

    void eaten() { 
        life_cnt--;
        cx = init_x;
        cy = init_y;
    }
};
class Ghost{
    const int TICK_PER_MOVE[4];
    const int TICK_PER_MOVE_FRIGHT[4];
    int cx, cy;
    int init_x, init_y;
    int gid;
    int next_tick;
    bool invisible_mode;
    int last_dir;
public:
    Ghost():
        TICK_PER_MOVE{130, 132, 134, 136},
        TICK_PER_MOVE_FRIGHT{195, 198, 201, 204}
    {}

    Ghost(int x, int y, int id) :
        TICK_PER_MOVE{130, 132, 134, 136},
        TICK_PER_MOVE_FRIGHT{195, 198, 201, 204},
        cx(x),
        cy(y),
        init_x(x),
        init_y(y),
        gid(id),
        next_tick(TICK_PER_MOVE[gid]),
        invisible_mode(false),
        last_dir(DOWN)
    {}

    int think() {
        return rand() % 4;
    }

    void move(const Field& field, int tick, bool is_fright) {
        if(tick == next_tick) {
            int r = think();

            if(last_dir == -1 || (last_dir + 2) % 4 != r) {
                int nx = cx + dx[r];
                int ny = cy + dy[r];
                if(field.valid(nx, ny)) {
                    cx = nx;
                    cy = ny;
                    goto after_move;
                }
            }

            {
                r = last_dir;
                int nx = cx + dx[r];
                int ny = cy + dy[r];
                if(field.valid(nx, ny)) {
                    cx = nx;
                    cy = ny;
                    goto after_move;
                }
            }

            for(r = 0; r < 4; r++) {
                int nx = cx + dx[r];
                int ny = cy + dy[r];
                if(field.valid(nx, ny)) {
                    cx = nx;
                    cy = ny;
                    goto after_move;
                }
            }

after_move:
            if(r >= 0 && r < 4) {
                last_dir = r;
            }
            if(is_fright) {
                next_tick += TICK_PER_MOVE_FRIGHT[gid];
            } else {
                next_tick += TICK_PER_MOVE[gid];
            }
        }
    }

    void action(int tick, bool is_fright) {
        if(invisible_mode && !is_fright) {
            invisible_mode = false;
        }
    }

    pair<int, int> coord() const {
        return {cx, cy};
    }

    bool is_invisible() const {
        return invisible_mode;
    }

    void eat() {
        assert(!invisible_mode);
        cx = init_x;
        cy = init_y;
    }

    void eaten() {
        assert(!invisible_mode);
        invisible_mode = true;
        cx = init_x;
        cy = init_y;
    }
};

class Game {
    AI man;
    vector<Ghost> ghosts;
    Field field;
    int score;
    const int EOL;
    public:
    Game(vector<string> init) :
        field(init),
        score(0),
        EOL(127 * field.width() * field.height() * 16)
    {
        for(int y = 0; y < field.height(); y++) {
            for(int x = 0; x < field.width(); x++) {
                if(init[y][x] == '\\') {
                    man = AI(x, y);
                }
                if(init[y][x] == '=') {
                    int id = ghosts.size();
                    ghosts.push_back(Ghost(x, y, id));
                }
            }
        }
    }
    void lose(int tick) {
        cout << "you lose..." << endl;
        cout << "TICK: " << tick << endl;
        cout << "SCORE: " << score << endl;
    }

    void win(int tick) {
        cout << "you win!!!" << endl;
        cout << "TICK: " << tick << endl;
        cout << "SCORE: " << score << endl;
    }

    void output(int tick){
        vector<string> grid = field.to_string();
        int cx, cy;
        tie(cx, cy) = man.coord();
        grid[cy][cx] = '\\'; // back slash
        for(const Ghost& ghost : ghosts) {
            tie(cx, cy) = ghost.coord();
            if(ghost.is_invisible()) {
                grid[cy][cx] = '~'; // 勝手に作った
            } else {
                grid[cy][cx] = '=';
            }
        }

        if(tick > 1) {
            for(int _ = 0; _ < field.height() + 3; _++) {
                cout << "\33[2A" << endl; // カーソルを上に1行移動
            }
        }

        cout << "Tick: " << tick << endl;
        cout << "Score: " << score << endl;
        cout << "Life: " << man.lives() << endl;
        for(int y = 0; y < field.height(); y++){
            cout << grid[y] << endl;
        }
    }

    void run() {
        for(int tick = 1; tick <= EOL; tick++) {
            // output
            output(tick);

            // Step1. All Lambda-Man and ghost moves scheduled for this tick take place.
            man.move(field, tick);
            for(Ghost& ghost : ghosts) {
                ghost.move(field, tick, man.is_fright());
            }

            // Step2. any actions (fright mode deactivating, fruit appearing/disappearing) take place.
            field.action(tick);
            man.action(tick);
            for(Ghost& ghost : ghosts) {
                ghost.action(tick, man.is_fright());
            }

            // Step3-1. If Lambda-Man occupies a square with a pill,
            // the pill is eaten by Lambda-Man and removed from the game.
            if(field.get(man.coord()) == PILL) {
                score += 10;
                field.set(man.coord(), EMPTY);
            }

            // Step3-2. If Lambda-Man occupies a square with a power pill,
            // the power pill is eaten by Lambda-Man, removed from the game, 
            // and fright mode is immediately activated, allowing Lambda-Man to eat ghosts.
            if(field.get(man.coord()) == P_PILL) {
                score += 50;
                field.set(man.coord(), EMPTY);
                man.set_fright(tick);
            }

            // Step3-3. If Lambda-Man occupies a square with a fruit,
            // the fruit is eaten by Lambda-Man, and removed from the game
            if(field.get(man.coord()) == FRUIT) {
                score += 100; // TODO: ステージによって点数を変える
                debug("score = %d", score);
                field.set(man.coord(), EMPTY);
            }


            // Step4. if one or more visible ghosts are on the same square as Lambda-Man,
            // then depending on whether or not fright mode is active,
            // Lambda-Man either loses a life or eats the ghost(s)
            for(Ghost& ghost : ghosts) {
                if(ghost.coord() == man.coord() && !ghost.is_invisible()){
                    // lambda man eats ghost
                    if(man.is_fright()) {
                        man.eat();
                        ghost.eaten();
                        assert(man.eat_count() >= 1);
                        score += min(1600, 200 * man.eat_count());
                        debug("turn = %d, score = %d", tick, score);
                    } else {
                    // lambda man are eaten
                        man.eaten();
                        for(Ghost& ghost_e : ghosts) {
                            ghost_e.eat();
                        }
                    }
                }
            }

            // Step5. if all the ordinary pills (ie not power pills) have been eaten, then Lambda-Man wins and the game is over.
            if(field.count(PILL) == 0) {
                win(tick);
                return ;
            }

            // Step6. if the number of Lambda-Man lives is 0, then Lambda-Man loses and the game is over
            if(man.lives() == 0) {
                lose(tick);
                return ;
            }

            // sleep(1);
        }
    }
};

int main(int argc, char* argv[]){
    if(argc <= 1) {
        cerr << "usage: " << argv[0] << " map_file" << endl;
        return 1;
    }
    ifstream ifs(argv[1]);
    vector<string> init;
    for(string s; getline(ifs, s);) {
        debug("%s", s.c_str());
        init.push_back(s);
    }
    debug("start game");
    Game game(init);
    game.run();
    return 0;
}

