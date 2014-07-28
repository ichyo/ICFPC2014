#include <bits/stdc++.h>
#include "log.h"
#include "reactive.h"
#define REP(i,n) for(int i=0; i<(int)(n); ++i)
#define debug(...)
using namespace std;
string ghost_command;
void sleep(int ms) {
    std::chrono::milliseconds dura( ms );
    std::this_thread::sleep_for( dura );
}


int dx[4] = {0, 1, 0, -1};
int dy[4] = {-1, 0, 1, 0};
enum BTYPE{
    WALL,
    EMPTY,
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

    inline int width() const {
        return W;
    }

    inline int height() const {
        return H;
    }

    inline int get(int x, int y) const  {
        return type[y][x];
    }

    inline int get(const pair<int, int>& coord) const  {
        return type[coord.second][coord.first];
    }

    inline int count(BTYPE b) const {
        return cnt[b];
    }

    inline void action(int tick) {
        // 移動と同時にフルーツは取れないらしい(参考 FAQ)ので1を足している(正しい?)
        if(tick == FIRST_FRUIT_AP + 1 || tick == SECOND_FRUIT_AP + 1) {
            set(fruit_coord, FRUIT);
        }else if(tick == FIRST_FRUIT_DP || tick == SECOND_FRUIT_DP) {
            set(fruit_coord, EMPTY);
        }
    }

    inline void set(int x, int y, BTYPE b) {
        cnt[ type[y][x] ]--;
        cnt[ b ] ++;
        type[y][x] = b;
    }

    inline void set(const pair<int, int>& coord, BTYPE b) {
        set(coord.first, coord.second, b);
    }

    inline bool valid(int x, int y) const {
        return 0 <= x && x < W && 0 <= y && y < H && type[y][x] != WALL;
    }

    vector<string> to_string() const {
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
    Reactive* R;
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
        last_dir(DOWN),
        R(new Reactive("./lambda_ai"))
    {}

    int think(const Field& field) {
        char str[256];
        sprintf(str, "%d %d\n", cx, cy);
        R->Write(str);
        R->Write("0\n");
        sprintf(str, "%d %d\n", field.height(), field.width());
        R->Write(str);
        vector<string> grid = field.to_string();
        for(string s : grid) {
            R->Write(s + "\n");
        }
        int t = stoi(R->Read());
        return t;
    }

    bool move(const Field& field, int tick) {
        if(tick == next_tick) {
            int r = think(field);
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
            return true;
        }
        return false;
    }

    inline pair<int, int> coord() {
        return {cx, cy};
    }

    inline bool is_fright() {
        return fright_mode;
    }

    inline void set_fright(int tick) {
        fright_mode = true;
        last_power_pill = tick;
    }

    inline void action(int tick) {
        if(tick == last_power_pill + FRIGHT_DURATION) {
            // fright モード 終わりの処理
            fright_mode = false;
            eat_cnt = 0;
        }
    }

    inline void eat() {
        eat_cnt ++;
    }

    inline int eat_count() const {
        return eat_cnt;
    }

    inline int lives() const {
        return life_cnt;
    }

    inline void eaten() { 
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
    Reactive* R;
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
        last_dir(DOWN),
        R(new Reactive(ghost_command))
    { }

    void close() {
        R->Write("game over");
    }

    int think(const Field& field, const vector<string>& response) {
        int r = last_dir;
        debug("ghost %d : think start", gid);

        R->Write("start\n");

        while(true) {
            string s = R->Read();
            debug("Reactive -> %s", s.c_str());
            if(s.find("hlt") != string::npos) break;
            stringstream ss(s);
            vector<string> v;
            while(ss >> s) v.push_back(s);
            assert(v[0] == "int");
            if(v[1] == "0") {
                r = stoi(v[2]);
            } else if(v[1] == "1") {
                R->Write(response[1] + "\n");
            } else if(v[1] == "2") {
                R->Write(response[2] + "\n");
            } else if(v[1] == "3") {
                R->Write(response[3] + "\n");
            } else if(v[1] == "4") {
                assert(false);
            } else if(v[1] == "5") {
                assert(false);
            } else if(v[1] == "6") {
                if(stoi(v[2]) == gid) { // 自分自身について
                    R->Write(to_string(invisible_mode * 2) + " " + to_string(last_dir) + "\n"); // TODO: fright_mode に未対応
                } else {
                    assert(false);
                }
            } else if(v[1] == "7") {
                R->Write(to_string(field.get(stoi(v[2]), stoi(v[3]))) + "\n");
            } else if(v[1] == "8") {
                assert(false);
            } else {
                assert(false);
            }

        }

        debug("ghost %d : think return %d", gid, r);
        return r;
    }

    inline int get_id(){
        return gid;
    }

    bool move(const Field& field, int tick, bool is_fright, const vector<string>& response) {
        if(tick == next_tick) {
            int r = think(field, response);

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

            for(r = 0; r < 4; r++) if((r + 2) % 4 != last_dir) {
                int nx = cx + dx[r];
                int ny = cy + dy[r];
                if(field.valid(nx, ny)) {
                    cx = nx;
                    cy = ny;
                    goto after_move;
                }
            }

            {
                r = (last_dir + 2) % 4;
                int nx = cx + dx[r];
                int ny = cy + dy[r];
                if(field.valid(nx, ny)) {
                    cx = nx;
                    cy = ny;
                    goto after_move;
                }
            }

            assert(false);

after_move:
            assert(r >= 0 && r < 4);
            last_dir = r;
            if(is_fright) {
                next_tick += TICK_PER_MOVE_FRIGHT[gid];
            } else {
                next_tick += TICK_PER_MOVE[gid];
            }
            return true;
        }
        return false;
    }

    inline void action(int tick, bool is_fright) {
        if(invisible_mode && !is_fright) {
            invisible_mode = false;
        }
    }

    inline pair<int, int> coord() const {
        return {cx, cy};
    }

    inline bool is_invisible() const {
        return invisible_mode;
    }

    inline void eat() {
        assert(!invisible_mode);
        cx = init_x;
        cy = init_y;

        last_dir = DOWN; // right??
    }

    inline void eaten() {
        assert(!invisible_mode);
        invisible_mode = true;
        cx = init_x;
        cy = init_y;

        last_dir = DOWN; // right??
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
                    debug("ghost %d make start", id);
                    ghosts.push_back(Ghost(x, y, id));
                    debug("ghost %d make end", id);
                }
            }
        }
    }
    void lose(int tick) {
        cout << "you lose..." << endl;
        cout << "TICK: " << tick << endl;
        cout << "SCORE: " << score << endl;
    }
    void timeover() {
        cout << "time over..." << endl;
        cout << "TICK: " << EOL << endl;
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

        if(tick > 140) {
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

    void close() {
        for(Ghost& g : ghosts) {
            g.close();
        }
    }

    void run() {
        for(int tick = 1; tick <= EOL; tick++) {
            bool updated = false;
            debug("start tick = %d", tick);

            // Step1. All Lambda-Man and ghost moves scheduled for this tick take place.
            updated |= man.move(field, tick);
            for(Ghost& ghost : ghosts) {
                vector<string> response(9);
                response[1] = to_string(man.coord().first) + " " + to_string(man.coord().second);
                response[2] = to_string(man.coord().first) + " " + to_string(man.coord().second); // I don't know
                response[3] = to_string(ghost.get_id());
                updated |= ghost.move(field, tick, man.is_fright(), response);
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
                debug("get pill : score %d", score);
            }

            // Step3-2. If Lambda-Man occupies a square with a power pill,
            // the power pill is eaten by Lambda-Man, removed from the game, 
            // and fright mode is immediately activated, allowing Lambda-Man to eat ghosts.
            if(field.get(man.coord()) == P_PILL) {
                score += 50;
                field.set(man.coord(), EMPTY);
                man.set_fright(tick);
                debug("get power pill : score %d", score);
            }

            // Step3-3. If Lambda-Man occupies a square with a fruit,
            // the fruit is eaten by Lambda-Man, and removed from the game
            if(field.get(man.coord()) == FRUIT) {
                score += 100; // TODO: ステージによって点数を変える
                field.set(man.coord(), EMPTY);
                debug("get fruit : score %d", score);
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
                        debug("lambda eat ghost %d : score = %d", ghost.get_id(), score);
                    } else {
                    // lambda man are eaten
                        man.eaten();
                        debug("ghost %d eat lambda", ghost.get_id());
                        for(Ghost& ghost_e : ghosts) {
                            ghost_e.eat();
                        }
                    }
                }
            }

            // Step5. if all the ordinary pills (ie not power pills) have been eaten, then Lambda-Man wins and the game is over.
            if(field.count(PILL) == 0) {
                debug("all pills have been eaten");
                win(tick);
                return ;
            }

            // Step6. if the number of Lambda-Man lives is 0, then Lambda-Man loses and the game is over
            if(man.lives() == 0) {
                debug("lambda lost all lives");
                lose(tick);
                return ;
            }

            if(updated) {
                output(tick);
                sleep(10);
            }
        }
        timeover();
    }
};

int main(int argc, char* argv[]){
    if(argc <= 2) {
        cerr << "usage: " << argv[0] << " map_file ghost_command" << endl;
        return 1;
    }
    ifstream ifs(argv[1]);
    ghost_command = string(argv[2]);
    debug("ghost_command = %s", ghost_command.c_str());

    vector<string> init;
    for(string s; getline(ifs, s);) {
        debug("%s", s.c_str());
        init.push_back(s);
    }

    debug("start game");
    Game game(init);
    game.run();
    game.close();
    return 0;
}

