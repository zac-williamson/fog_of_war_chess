use crate::{GameState, move, MoveData, UserState};
use crate::piece::{Piece, PieceData, Pieces};
use crate::update_vision::{get_piece_data, update_vision, update_vision_for_piece};
use crate::validate_move::validate_move_and_update_board_state;
use crate::vision_table::VISION_TABLE;
use mpclib::selective_disclosure::selective_disclosure::{RoundState, UserOutputState};
// // 1 million gates!
// // 877k if player_id is constant. yuck

// now down to 409,573

// consume opponent move = 173k
// validate_move_and_update_board_state = 20k
// update_vision = 28k
// create_round_commitments = 151k
// update2 = 23k

// total from estimate = 395k
// looks like this is about as good as we can do without changing mpclib. hmm
#[export]
fn bench_move(
    game_state: GameState,
    alice_state: UserState,
    alice_move: MoveData,
    player_id: Field,
) -> (GameState, UserState, Field, Field) {
    move(game_state, alice_state, alice_move, player_id)
}

// 23,211
#[export]
fn bench_update2(
    input_state: GameState,
    white_output_state: UserOutputState<64, 2>,
    player_id: Field,
) -> RoundState<64, 2> {
    input_state.mpc_state.update2(white_output_state, player_id as u32)
}

#[export]
fn bench_create_round_commitments(
    input_state: GameState,
    user_state: UserState,
    visible_squares: [Field; 64],
    player_id: Field,
) -> UserOutputState<64, 2> {
    mpclib::selective_disclosure::selective_disclosure::create_round_commitments(
        user_state.encode_game_state(),
        visible_squares,
        user_state.encrypt_secret,
        user_state.mask_secret,
        input_state.mpc_state,
        player_id as u32,
    )
}
// // 172972
// #[export]
// fn bench_consume_opponent_move_and_update_game_state(
//     input_state: GameState,
//     user_state: UserState,
//     player_id: Field,
// ) -> UserState {
//     consume_opponent_move_and_update_game_state(input_state, user_state, player_id)
// }

// 52697
// now 19,517
#[export]
fn bench_validate_move_and_update_board_state(
    user_state: UserState,
    starting_piece_data: PieceData,
    ending_piece_data: PieceData,
    player_id: Field,
) -> [Piece; 64] {
    validate_move_and_update_board_state(
        user_state.game_state,
        starting_piece_data,
        ending_piece_data,
        player_id,
    )
}

// 40,860 gates!
// now 1,405 great
#[export]
fn bench_get_piece_data(pieces: [Piece; 64], player_id: Field) -> [PieceData; 16] {
    get_piece_data(pieces, player_id)
}
// 634,201 AHA
// 75,194
// after updates almost -560,000 gates. nice. still high though
// now 27,747 after get piece data fixed
#[export]
fn bench_update_vision(user_state: UserState, player_id: Field) -> [Field; 64] {
    update_vision(user_state.game_state, player_id)
}

// 39281
// updated is 11,587
// down to 7,108
#[export]
fn bench_update_vision_for_piece(
    vision: [Field; 64],
    pieces: [Piece; 64],
    piece_data: PieceData,
) -> [Field; 64] {
    let mut r = vision;
    update_vision_for_piece(&mut r, pieces, piece_data);
    r
}

// unconstrained fn __to_bool(inp: Field) -> bool {
//     inp as bool
// }

// fn to_bool(inp: Field) -> bool {
//     // Safety:
//     let r = unsafe { __to_bool(inp) };
//     assert_eq(r as Field, inp);
//     r
// }
// this is 4k
#[export]
fn bench_part(
    input_vision: [Field; 64],
    pieces: [Piece; 64],
    piece_data: PieceData,
) -> [Field; 64] {
    let mut output_vision: [Field; 64] = input_vision;

    let x = piece_data.x;
    let y = piece_data.y;
    let piece_id = piece_data.id - 1;
    let vision_idx = piece_id * 64 + (x as Field) + (y as Field * 8);
    let vision_idx = vision_idx * piece_data.exists as Field;
    let vision_vector_f = VISION_TABLE[vision_idx];
    let vision_vector: [u1; 64] = vision_vector_f.to_le_bits();

    if (piece_data.exists as bool) {
        output_vision[x + (y * 8)] = 1;
    }

    let piece_exists = piece_data.exists as Field;
    // // north-west
    let mut vision_blocked: [Field; 8] = [0; 8];

    for i in 0..7 {
        let locations: [Field; 8] = [
            (x + i as Field + 1) + ((y + i as Field + 1) * 8), // north west
            (x + i as Field + 1) + ((y - i as Field - 1) * 8), // south west
            (x - i as Field - 1) + ((y + i as Field + 1) * 8), // north east
            (x - i as Field - 1) + ((y - i as Field - 1) * 8), // south east
            (x as Field) + ((y + i as Field + 1) * 8), // north
            (x as Field) + (y - i as Field - 1) * 8, // south
            (x + i as Field + 1) + (y * 8), // east
            (x - i as Field - 1) + (y * 8), // west
        ];

        for j in 0..8 {
            let location = locations[j];
            std::as_witness(location);
            let location_valid = vision_vector[i + (7 * j)] as Field;
            let bounded_location = location * location_valid;
            let square_empty = (pieces[bounded_location].id == Pieces::EMPTY_SQUARE) as Field;
            let mut blocked: Field = vision_blocked[j];
            let execute = (piece_exists * location_valid);
            std::as_witness(execute);
            let execute = execute - execute * blocked;
            std::as_witness(execute);
            let mut visible = output_vision[bounded_location];
            let updated_visible = (execute + visible - visible * execute);
            output_vision[bounded_location] = updated_visible;
            let is_blocked = execute * (1 - square_empty as Field);
            std::as_witness(is_blocked);
            let updated_blocked = blocked * (1 - is_blocked) + is_blocked;
            vision_blocked[j] = updated_blocked;
        }
    }
    let knight_locations_valid: [u1; 8] = [
        vision_vector[56],
        vision_vector[57],
        vision_vector[58],
        vision_vector[59],
        vision_vector[60],
        vision_vector[61],
        vision_vector[62],
        vision_vector[63],
    ];

    let knight_locations: [Field; 8] = [
        ((x + 2) + (y + 1) * 8) * knight_locations_valid[0] as Field,
        ((x + 1) + (y + 2) * 8) * knight_locations_valid[1] as Field,
        ((x - 1) + (y + 2) * 8) * knight_locations_valid[2] as Field,
        ((x - 2) + (y + 1) * 8) * knight_locations_valid[3] as Field,
        ((x + 2) + (y - 1) * 8) * knight_locations_valid[4] as Field,
        ((x + 1) + (y - 2) * 8) * knight_locations_valid[5] as Field,
        ((x - 1) + (y - 2) * 8) * knight_locations_valid[6] as Field,
        ((x - 2) + (y - 1) * 8) * knight_locations_valid[7] as Field,
    ];

    for i in 0..8 {
        let location_valid = knight_locations_valid[i] as Field;
        let piece_exists = piece_data.exists as Field;
        let is_knight = (piece_data.id == Pieces::KNIGHT) as Field;
        let execute = location_valid * piece_exists * is_knight;

        let vision = output_vision[knight_locations[i]];

        let updated_vision = vision * (1 - execute) + execute;
        output_vision[knight_locations[i]] = updated_vision;
    }

    output_vision
}
