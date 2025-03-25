use crate::{
    consume_opponent_move_and_update_game_state, GameState, move, MoveData, Piece, PieceData,
    Pieces, update_vision, update_vision_for_piece, UserState, validate_move_and_update_board_state,
    VISION_TABLE, WHITE_PLAYER_ID,
};

// // 1 million gates!
// // 877k if player_id is constant. yuck
// #[export]
// fn bench_move(
//     game_state: GameState,
//     alice_state: UserState,
//     alice_move: MoveData,
//     player_id: Field,
// ) -> (GameState, UserState, Field, Field) {
//     move(game_state, alice_state, alice_move, player_id)
// }

// // 172972
// #[export]
// fn bench_consume_opponent_move_and_update_game_state(
//     input_state: GameState,
//     user_state: UserState,
//     player_id: Field,
// ) -> UserState {
//     consume_opponent_move_and_update_game_state(input_state, user_state, player_id)
// }

// // 52697
// #[export]
// fn bench_validate_move_and_update_board_state(
//     user_state: UserState,
//     starting_piece_data: PieceData,
//     ending_piece_data: PieceData,
//     player_id: Field,
// ) -> [Piece; 64] {
//     validate_move_and_update_board_state(
//         user_state.game_state,
//         starting_piece_data,
//         ending_piece_data,
//         player_id,
//     )
// }

// // 634201 AHA
// #[export]
// fn bench_update_vision(user_state: UserState, player_id: Field) -> [Field; 64] {
//     update_vision(user_state.game_state, player_id)
// }

// // 39281
// #[export]
// fn bench_update_vision_for_piece(
//     vision: [Field; 64],
//     pieces: [Piece; 64],
//     piece_data: PieceData,
// ) -> [Field; 64] {
//     update_vision_for_piece(vision, pieces, piece_data)
// }

unconstrained fn __to_bool(inp: Field) -> bool {
    inp as bool
}

fn to_bool(inp: Field) -> bool {
    // Safety:
    let r = unsafe { __to_bool(inp) };
    assert_eq(r as Field, inp);
    r
}
#[export]
fn bench_part(input_vision: [Field; 64], pieces: [Piece; 64], piece_data: PieceData) {
    let mut output_vision: [Field; 64] = input_vision;

    let x = piece_data.x;
    let y = piece_data.y;
    let piece_id = piece_data.id - 1;
    let vision_idx = piece_id * 64 + (x as Field) + (y as Field * 8);
    let vision_idx = vision_idx * piece_data.exists as Field;
    let vision_vector_f = VISION_TABLE[vision_idx];
    let vision_vector: [u1; 64] = vision_vector_f.to_le_bits();

    if (piece_data.exists) {
        output_vision[x + (y * 8)] = 1;
    }

    // 6997 1 iteration
    // // north-west
    let mut vision_blocked: [bool; 8] = [false; 8];
    for i in 0..7 {
        let location: Field = (x + i as Field + 1) + ((y + i as Field + 1) * 8);
        let location_valid = vision_vector[i];

        let bounded_location = location * location_valid as Field;
        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[0] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[0] = true;
            }
        }
    }
    // 10947
    // into 7676
    // lol
    //about 4k for this section what?
    // south west
    for i in 0..7 {
        let location: Field = (x + i as Field + 1) + ((y - i as Field - 1) * 8);
        let location_valid = vision_vector[i + 7];

        let bounded_location = location * location_valid as Field;

        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        let mut blocked = vision_blocked[1];

        let execute =
            (location_valid as Field * (1 - blocked as Field)) * (piece_data.exists as Field);

        let mut visible = output_vision[bounded_location];

        let mut updated_visible = visible * (1 - execute) + execute;
        output_vision[bounded_location] = updated_visible;

        let is_blocked = execute * square_empty as Field;
        let mut updated_blocked: Field = blocked as Field * (1 - is_blocked) + is_blocked;
        vision_blocked[1] = to_bool(updated_blocked);
        if ((location_valid == 1) & !vision_blocked[1] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[1] = true;
            }
        }
    }

    println(f"{output_vision}, {vision_blocked}");
}
