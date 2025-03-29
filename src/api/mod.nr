use crate::{
    consume_opponent_move_and_update_game_state as consume_opponent_move_and_update_game_state_inner,
    GameState, MoveData, UserState,
};
use crate::piece::{PieceData, Pieces};
use crate::validate_move::validate_move_and_update_board_state;
use std::hash::poseidon2::Poseidon2::hash as poseidon2;

/// When Alice has made a move, Bob uses this function to recover game state from Alice that he is able to see
#[export]
pub fn consume_opponent_move_and_update_game_state(
    input_state: GameState,
    user_state: UserState,
    player_id: Field,
) -> UserState {
    consume_opponent_move_and_update_game_state_inner(input_state, user_state, player_id)
}

#[export]
pub fn empty_game_state() -> GameState {
    GameState::default()
}

#[export]
pub fn empty_white_state() -> UserState {
    let u = UserState::default();
    u.initialize(0)
}

#[export]
pub fn empty_black_state() -> UserState {
    let u = UserState::default();
    u.initialize(1)
}

/// Call this fn to update a GameState object to contain a player's secret hashes
#[export]
pub fn commit_to_user_secrets(
    game_state: GameState,
    encrypt_secret: Field,
    mask_secret: Field,
    player_id: Field,
) -> GameState {
    let mut updated = game_state;

    let secret_hashes = [poseidon2([encrypt_secret, -1], 2), poseidon2([mask_secret, -1], 2)];
    updated.mpc_state.user_encrypt_secret_hashes[player_id] = secret_hashes[0];
    updated.mpc_state.user_mask_secret_hashes[player_id] = secret_hashes[1];
    updated
}

#[export]
pub fn create_move(x1: Field, y1: Field, x2: Field, y2: Field) -> MoveData {
    MoveData { x1, y1, x2, y2 }
}

/// Recover a user's new UserState after they have made a move.
#[export]
pub fn update_user_state_from_move(
    is_first_two_moves: bool,
    user_state: UserState,
    move_data: MoveData,
    player_id: Field,
) -> (UserState) {
    let mut user_state = user_state;
    if (is_first_two_moves) {
        user_state = UserState::initialize(user_state, player_id);
    }
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
    user_state
}
