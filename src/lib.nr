mod benchmarks;

use mpclib::selective_disclosure::selective_disclosure::{
    consume_round_commitments, create_round_commitments, RoundState, UserOutputState,
};

use crate::validate_move::validate_move_and_update_board_state;

use crate::piece::{Piece, PieceData, Pieces};

mod update_vision;
mod vision_table;
mod piece;
mod validate_move;
mod api;

use update_vision::update_vision;

use std::hash::poseidon2::Poseidon2::hash as poseidon2;

type RoundMpcState = RoundState<64, 2>;
pub struct GameState {
    pub game_ended: bool,
    pub move_count: Field,
    pub mpc_state: RoundMpcState,
}
impl std::default::Default for GameState {
    fn default() -> Self {
        GameState { game_ended: false, move_count: 0, mpc_state: RoundMpcState::default() }
    }
}

impl GameState {
    pub fn hash(self) -> Field {
        let buffer: [Field; 3] = [self.game_ended as Field, self.move_count, self.mpc_state.hash()];
        poseidon2(buffer, 3)
    }
    pub fn commit_to_user_secrets(
        self,
        encrypt_secret: Field,
        mask_secret: Field,
        player_id: Field,
    ) -> GameState {
        let mut updated = self;

        let secret_hashes = [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];
        updated.mpc_state.user_encrypt_secret_hashes[player_id] = secret_hashes[0];
        updated.mpc_state.user_mask_secret_hashes[player_id] = secret_hashes[1];
        updated
    }
}

pub struct MoveData {
    pub x1: Field,
    pub y1: Field,
    pub x2: Field,
    pub y2: Field,
}
impl MoveData {
    fn new(x1: Field, y1: Field, x2: Field, y2: Field) -> Self {
        MoveData { x1, y1, x2, y2 }
    }
}

pub struct UserState {
    pub encrypt_secret: Field,
    pub mask_secret: Field,
    pub visible_squares: [Field; 64],
    pub game_state: [Piece; 64],
}

impl std::default::Default for UserState {
    fn default() -> Self {
        UserState {
            encrypt_secret: 0,
            mask_secret: 0,
            visible_squares: [0; 64],
            game_state: [Piece::default(); 64],
        }
    }
}

impl UserState {

    pub(crate) fn initialize(self, player_id: Field) -> Self {
        let first_32_square_visibility = 1 - player_id;
        let last_32_square_visibility = player_id;
        assert_eq(WHITE_PLAYER_ID, 0);
        assert_eq(BLACK_PLAYER_ID, 1);
        let mut visibility: [Field; 64] = [0; 64];
        for i in 0..32 {
            visibility[i] = first_32_square_visibility;
            visibility[i + 32] = last_32_square_visibility;
        }

        let white_game_state: [Piece; 16] = [
            Piece { id: Pieces::ROOK, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::KNIGHT, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BISHOP, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::QUEEN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::KING, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BISHOP, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::KNIGHT, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::ROOK, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::WHITE_PAWN, player_id: WHITE_PLAYER_ID, has_moved: 0 },
        ];

        let black_game_state: [Piece; 16] = [
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BLACK_PAWN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::ROOK, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::KNIGHT, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BISHOP, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::QUEEN, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::KING, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::BISHOP, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::KNIGHT, player_id: BLACK_PLAYER_ID, has_moved: 0 },
            Piece { id: Pieces::ROOK, player_id: BLACK_PLAYER_ID, has_moved: 0 },
        ];

        let mut game_state: [Piece; 64] = [Piece::default(); 64];
        for i in 0..16 {
            if (player_id == WHITE_PLAYER_ID) {
                game_state[i] = white_game_state[i];
            } else {
                game_state[i + 48] = black_game_state[i];
            }
        }
        UserState {
            encrypt_secret: self.encrypt_secret,
            mask_secret: self.mask_secret,
            visible_squares: visibility,
            game_state,
        }
    }

    fn encode_game_state(self) -> [Field; 64] {
        let mut r: [Field; 64] = [0; 64];
        for i in 0..64 {
            r[i] = self.game_state[i].encode();
        }
        r
    }

    fn hash(self) -> Field {
        let encoded = self.encode_game_state();

        let mut hash_buffer: [Field; 130] = [0; 130];
        for i in 0..64 {
            hash_buffer[i] = encoded[i];
            hash_buffer[i + 64] = self.visible_squares[i];
        }
        hash_buffer[128] = self.encrypt_secret;
        hash_buffer[129] = self.mask_secret;
        poseidon2(hash_buffer, 130)
    }
}
global BLACK_PLAYER_ID: Field = 1;
global WHITE_PLAYER_ID: Field = 0;

struct AdditionalMoveData {
    extra_state_update: PieceData,
    extra_state_update_needed: bool,
    extra_state_removal: PieceData,
    extra_state_removal_needed: bool,
}
impl std::default::Default for AdditionalMoveData {
    fn default() -> Self {
        AdditionalMoveData {
            extra_state_update: PieceData::default(),
            extra_state_update_needed: false,
            extra_state_removal: PieceData::default(),
            extra_state_removal_needed: false,
        }
    }
}

pub fn consume_opponent_move_and_update_game_state(
    input_state: GameState,
    user_state: UserState,
    player_id: Field,
) -> UserState {
    let opponent_output_state = consume_round_commitments(
        user_state.mask_secret,
        input_state.mpc_state,
        player_id as u32,
    );

    let mut new_state = user_state;
    // We don't need to check the move is legal, as black will have validated this when making a move proof
    // TODO: EN PASSANT DOES NOT WORK BECAUSE WE NEED TO DELETE A SQUARE AND REPLACE WITH NOTHING
    for i in 0..64 {
        let is_some = opponent_output_state[0][i].is_some() as Field;
        // if (opponent_output_state[0][i].is_some()) {
        let decoded_packed = opponent_output_state[0][i].unwrap_unchecked();
        let decoded: Piece = Piece::decode(decoded_packed);

        let decoded_is_empty = (decoded.id == Pieces::EMPTY_SQUARE) as Field;
        let original_square_is_not_empty =
            (user_state.game_state[i].id != Pieces::EMPTY_SQUARE) as Field;
        let original_square_not_player = (user_state.game_state[i].player_id != player_id) as Field;

        let update_square = (1 - decoded_is_empty) * is_some;
        let delete_square =
            decoded_is_empty * original_square_is_not_empty * original_square_not_player * is_some;
        std::as_witness(update_square);
        std::as_witness(delete_square);
        let leave_square_alone = (1 - update_square) * (1 - delete_square);
        std::as_witness(leave_square_alone);

        let original_packed = user_state.game_state[i].encode();

        let updated_square = original_packed * leave_square_alone + decoded_packed * update_square;

        // if leave_square_alone, piece is opponent piece and square is not visible, make square invisible
        let square_not_visible = (user_state.visible_squares[i] == 0) as Field;
        let lost_vision_on_square = square_not_visible
            * (1 - is_some)
            * original_square_is_not_empty
            * original_square_not_player;
        let updated_square = updated_square * (1 - lost_vision_on_square);
        new_state.game_state[i] = Piece::decode(updated_square);
    }

    new_state
}

unconstrained fn __div2(input: Field) -> u32 {
    let r = input as u32;
    r / 2
}

pub struct MoveHashes {
    pub input_game_state: Field,
    pub input_user_state: Field,
    pub output_game_state: Field,
    pub output_user_state: Field,
}
impl std::default::Default for MoveHashes {
    fn default() -> Self {
        MoveHashes {
            input_game_state: 0,
            input_user_state: 0,
            output_game_state: 0,
            output_user_state: 0,
        }
    }
}

pub fn move(
    input_state: GameState,
    user_state: UserState,
    move_data: MoveData,
    player_id: Field,
) -> (GameState, MoveHashes) {
    let input_state_hash = input_state.hash();
    let input_user_state_hash = user_state.hash();
    assert((player_id == WHITE_PLAYER_ID) | (player_id == BLACK_PLAYER_ID));
    assert_eq(input_state.game_ended, false);
    // Safety: cheapish check to see if player_id is correct. If move_count = even, white's turn. odd = black's turn
    let move_count_div2 = unsafe { __div2(input_state.move_count) };
    assert_eq(move_count_div2 as Field * 2 + player_id, input_state.move_count);
    let mut user_state = user_state;
    if ((input_state.move_count == 0) | (input_state.move_count == 1)) {
        user_state = UserState::initialize(user_state, player_id);
    }

    // TODO: we need to validate that the provided user state is the same as a user state value that white previously committed to
    // we can just output the user state hash and the game state hash and have a higher level fn handle it
    move_data.x1.assert_max_bit_size::<3>();
    move_data.x2.assert_max_bit_size::<3>();
    move_data.y1.assert_max_bit_size::<3>();
    move_data.y2.assert_max_bit_size::<3>();

    let mut user_state: UserState =
        consume_opponent_move_and_update_game_state(input_state, user_state, player_id);

    // Validate Move
    // Update Game State
    let starting_piece = user_state.game_state[move_data.x1 + move_data.y1 * 8];
    // let ending_piece = user_state.game_state[move_data.x2 + move_data.y2 * 8];
    let starting_piece_data: PieceData =
        PieceData { id: starting_piece.id, x: move_data.x1, y: move_data.y1, exists: 1 };
    let ending_piece_data: PieceData =
        PieceData { id: starting_piece.id, x: move_data.x2, y: move_data.y2, exists: 1 };

    let existing_end_piece = user_state.game_state[move_data.x2 + move_data.y2 * 8];
    let mut game_ended = false;
    if ((existing_end_piece.id == Pieces::KING) & (existing_end_piece.player_id != player_id)) {
        game_ended = true;
    }

    user_state.game_state = validate_move_and_update_board_state(
        user_state.game_state,
        starting_piece_data,
        ending_piece_data,
        player_id,
    );
    // If black has moved and captured a white piece, whice's mask vector needs to be updated
    let visible_squares = update_vision(user_state.game_state, player_id);

    // validate_move_and_update_board_state(user_state.encoded_pieces)
    // when used inside a Noir program, previous_round_hash should be sourced from a pub variable
    // assert_eq(previous_round_hash, round_state.hash());

    // TODO this logic should be wrapped in a helper function
    assert_eq(
        std::hash::poseidon2::Poseidon2::hash([user_state.encrypt_secret, -1], 2),
        input_state.mpc_state.user_encrypt_secret_hashes[player_id],
    );
    assert_eq(
        std::hash::poseidon2::Poseidon2::hash([user_state.mask_secret, -1], 2),
        input_state.mpc_state.user_mask_secret_hashes[player_id],
    );
    let white_output_state: UserOutputState<64, 2> = create_round_commitments(
        user_state.encode_game_state(),
        visible_squares,
        user_state.encrypt_secret,
        user_state.mask_secret,
        input_state.mpc_state,
        player_id as u32,
    );

    let output_mpc_state = input_state.mpc_state.update2(white_output_state, player_id as u32);

    let mut output_state = GameState {
        game_ended,
        move_count: input_state.move_count + 1,
        mpc_state: output_mpc_state,
    };

    (
        output_state,
        MoveHashes {
            input_game_state: input_state_hash,
            input_user_state: input_user_state_hash,
            output_game_state: output_state.hash(),
            output_user_state: user_state.hash(),
        },
    )
    // need to validate move.
    // if Castle, or En Passant, 2 states need to be updated

    // White has received Black's mask commitments (what black wants to see from white)
}

pub fn empty_game_state() -> GameState {
    GameState::default()
}

#[test]
fn test_move() {
    let mut game_state: GameState = empty_game_state();

    let mut alice_state: UserState = UserState::default();
    let mut bob_state: UserState = UserState::default();

    alice_state.encrypt_secret = poseidon2([1], 1);
    alice_state.mask_secret = poseidon2([2], 1);
    bob_state.encrypt_secret = poseidon2([3], 1);
    bob_state.mask_secret = poseidon2([4], 1);

    game_state =
        game_state.commit_to_user_secrets(alice_state.encrypt_secret, alice_state.mask_secret, 0);
    game_state =
        game_state.commit_to_user_secrets(bob_state.encrypt_secret, bob_state.mask_secret, 1);

    // alice moves pawn

    let mut hashes: [MoveHashes; 10] = [MoveHashes::default(); 10];
    let alice_move: MoveData = MoveData { x1: 4, y1: 1, x2: 4, y2: 3 };
    let m = move(game_state, alice_state, alice_move, WHITE_PLAYER_ID);
    game_state = m.0;
    hashes[0] = m.1;
    let mut alice_state =
        api::update_user_state_from_move(true, alice_state, alice_move, WHITE_PLAYER_ID);

    // bob updates her state after receiving alice's move output
    let mut bob_new_state =
        consume_opponent_move_and_update_game_state(game_state, bob_state, BLACK_PLAYER_ID);

    let bob_move: MoveData = MoveData { x1: 4, y1: 6, x2: 4, y2: 4 };
    let m = move(game_state, bob_state, bob_move, BLACK_PLAYER_ID);
    game_state = m.0;
    hashes[1] = m.1;
    bob_state = api::update_user_state_from_move(true, bob_new_state, bob_move, BLACK_PLAYER_ID);
    // // alice updates her state after receiving bob's move output
    let alice_new_state =
        consume_opponent_move_and_update_game_state(game_state, alice_state, WHITE_PLAYER_ID);

    // alice moves queen to H5
    let alice_move = MoveData { x1: 3, y1: 0, x2: 7, y2: 4 };
    let m = move(game_state, alice_state, alice_move, WHITE_PLAYER_ID);
    game_state = m.0;
    hashes[2] = m.1;
    alice_state =
        api::update_user_state_from_move(false, alice_new_state, alice_move, WHITE_PLAYER_ID);
    // // bob updates her state after receiving alice's move output
    let bob_new_state =
        consume_opponent_move_and_update_game_state(game_state, bob_state, BLACK_PLAYER_ID);

    // bob moves pawn to F5
    let bob_move = MoveData { x1: 5, y1: 6, x2: 5, y2: 5 };
    let m = move(game_state, bob_state, bob_move, BLACK_PLAYER_ID);
    game_state = m.0;
    hashes[3] = m.1;
    bob_state = api::update_user_state_from_move(false, bob_new_state, bob_move, BLACK_PLAYER_ID);
    // alice moves queen to E8, checkmate

    let alice_new_state =
        consume_opponent_move_and_update_game_state(game_state, alice_state, WHITE_PLAYER_ID);

    let alice_move = MoveData { x1: 7, y1: 4, x2: 4, y2: 7 };
    let m = move(game_state, alice_state, alice_move, WHITE_PLAYER_ID);
    game_state = m.0;
    hashes[4] = m.1;
    alice_state =
        api::update_user_state_from_move(false, alice_new_state, alice_move, WHITE_PLAYER_ID);
    assert_eq(game_state.game_ended, true);
    // // alice updates her state after receiving bob's move output
    // let alice_state =
    //     consume_opponent_move_and_update_game_state(game_state, alice_state, WHITE_PLAYER_ID);

    println(f"hashes = {hashes}");
    assert_eq(hashes[0].output_game_state, hashes[1].input_game_state);
    assert_eq(hashes[1].output_game_state, hashes[2].input_game_state);
    assert_eq(hashes[2].output_game_state, hashes[3].input_game_state);
    assert_eq(hashes[3].output_game_state, hashes[4].input_game_state);

    assert_eq(hashes[0].output_user_state, hashes[2].input_user_state);
    assert_eq(hashes[1].output_user_state, hashes[3].input_user_state);
    assert_eq(hashes[2].output_user_state, hashes[4].input_user_state);
}
