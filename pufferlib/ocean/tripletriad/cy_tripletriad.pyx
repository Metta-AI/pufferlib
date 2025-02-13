from libc.stdlib cimport calloc, free

cdef extern from "tripletriad.h":
    int LOG_BUFFER_SIZE

    ctypedef struct Log:
        float episode_return;
        float episode_length;
        float score;

    ctypedef struct LogBuffer
    LogBuffer* allocate_logbuffer(int)
    void free_logbuffer(LogBuffer*)
    Log aggregate_and_clear(LogBuffer*)

    ctypedef struct CTripleTriad:
        float* observations
        int* actions
        float* rewards
        unsigned char* dones
        LogBuffer* log_buffer
        Log log
        int card_width;
        int card_height;
        float* board_x;
        float* board_y;
        int** board_states;
        int width;
        int height;
        int game_over;
        int num_cards;
        int*** cards_in_hand;
        int* card_selected;
        int** card_locations;
        int* action_masks;
        int*** board_card_values;
        int* score;

    ctypedef struct Client

    CTripleTriad* init_ctripletriad(CTripleTriad* env)
    void free_ctripletriad(CTripleTriad* env)

    Client* make_client(float width, float height)
    void close_client(Client* client)
    void c_render(Client* client, CTripleTriad* env)
    void c_reset(CTripleTriad* env)
    void c_step(CTripleTriad* env)

cdef class CyTripleTriad:
    cdef:
        CTripleTriad* envs
        Client* client  
        LogBuffer* logs
        int num_envs

    def __init__(self, float[:, :] observations, int[:] actions,
            float[:] rewards, unsigned char[:] terminals, int num_envs,
            int width, int height, int card_width, int card_height):

        self.num_envs = num_envs
        self.client = NULL
        self.envs = <CTripleTriad*> calloc(num_envs, sizeof(CTripleTriad))
        self.logs = allocate_logbuffer(LOG_BUFFER_SIZE)

        cdef int i
        for i in range(num_envs):
            self.envs[i] = CTripleTriad(
                observations=&observations[i, 0],
                actions=&actions[i],
                rewards=&rewards[i],
                dones=&terminals[i],
                log_buffer=self.logs,
                width=width,
                height=height,
                card_width=card_width,
                card_height=card_height,
                num_cards=10,
            )
            init_ctripletriad(&self.envs[i])

    def reset(self):
        cdef int i
        for i in range(self.num_envs):
            c_reset(&self.envs[i])

    def step(self):
        cdef int i
        for i in range(self.num_envs):
            c_step(&self.envs[i])

    def render(self):
        cdef CTripleTriad* env = &self.envs[0]
        if self.client == NULL:
            self.client = make_client(env.width, env.height)

        c_render(self.client, env)

    def close(self):
        if self.client != NULL:
            close_client(self.client)
            self.client = NULL

        # Todo: clean
        for i in range(self.num_envs):
            free_ctripletriad(&self.envs[i])
        free(self.envs)

    def log(self):
        cdef Log log = aggregate_and_clear(self.logs)
        return log
