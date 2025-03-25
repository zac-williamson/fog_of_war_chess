mod benchmarks;

use mpclib::selective_disclosure::selective_disclosure::{
    commit, commit_mask, consume_round_commitments, create_round_commitments, execute_round,
    reveal_mask, RoundState, update_mask, UserOutputState,
};

pub(crate) mod Pieces {
    pub(crate) global EMPTY_SQUARE: Field = 0;
    pub(crate) global WHITE_PAWN: Field = 1;
    pub(crate) global BLACK_PAWN: Field = 2;
    pub(crate) global KNIGHT: Field = 3;
    pub(crate) global BISHOP: Field = 4;
    pub(crate) global ROOK: Field = 5;
    pub(crate) global QUEEN: Field = 6;
    pub(crate) global KING: Field = 7;
}

unconstrained fn encode_bits_into_field(bits: [bool; 64]) -> Field {
    let mut r: Field = 0;
    for i in 0..64 {
        r = r * 2;
        r += bits[63 - i] as Field;
    }
    r
}
comptime global VISION_TABLE: [Field; 448] = get_vision_table();

unconstrained comptime fn get_vision_table() -> [Field; 64 * 7] {
    let mut r: [Field; 448] = [0; 448];

    // given a piece ID and a square, we want a list of all squares that are visible
    // pawn
    // let pawn_vision:
    for x in 0..8 {
        for y in 0..8 {
            let mut queen_vision_vector: [bool; 64] = [false; 64];
            let mut bishop_vision_vector: [bool; 64] = [false; 64];
            let mut rook_vision_vector: [bool; 64] = [false; 64];
            let mut king_vision_vector: [bool; 64] = [false; 64];
            let mut knight_vision_vector: [bool; 64] = [false; 64];
            let mut white_pawn_vision_vector: [bool; 64] = [false; 64];
            let mut black_pawn_vision_vector: [bool; 64] = [false; 64];

            for i in 0..7 {
                let x_east = x + i + 1;
                //  let x_west: u32 = x - i;
                let y_north = y + i + 1;

                let x_east_in_range = x_east < 8;
                let x_west_in_range = x >= i + 1; //x < (8 + i + 1);
                let y_north_in_range = y_north < 8;
                let y_south_in_range = y >= i + 1; //y < (8 + i + 1);

                // y - i - 1 must be less than 8 and greater than 0
                // y - i - 1 > 0
                // y > i + 1

                // y - i - 1 >= 0
                // y >= i + 1
                queen_vision_vector[i] = x_east_in_range & y_north_in_range;
                queen_vision_vector[i + 7] = x_east_in_range & y_south_in_range;
                queen_vision_vector[i + 14] = x_west_in_range & y_north_in_range;
                queen_vision_vector[i + 21] = x_west_in_range & y_south_in_range;
                queen_vision_vector[i + 28] = y_north_in_range;
                queen_vision_vector[i + 35] = y_south_in_range;
                queen_vision_vector[i + 42] = x_east_in_range;
                queen_vision_vector[i + 49] = x_west_in_range;

                bishop_vision_vector[i] = x_east_in_range & y_north_in_range;
                bishop_vision_vector[i + 7] = x_east_in_range & y_south_in_range;
                bishop_vision_vector[i + 14] = x_west_in_range & y_north_in_range;
                bishop_vision_vector[i + 21] = x_west_in_range & y_south_in_range;

                rook_vision_vector[i + 28] = y_north_in_range;
                rook_vision_vector[i + 35] = y_south_in_range;
                rook_vision_vector[i + 42] = x_east_in_range;
                rook_vision_vector[i + 49] = x_west_in_range;

                if (i == 0) {
                    king_vision_vector[i] = x_east_in_range & y_north_in_range;
                    king_vision_vector[i + 7] = x_east_in_range & y_south_in_range;
                    king_vision_vector[i + 14] = x_west_in_range & y_north_in_range;
                    king_vision_vector[i + 21] = x_west_in_range & y_south_in_range;
                    king_vision_vector[i + 28] = y_north_in_range;
                    king_vision_vector[i + 35] = y_south_in_range;
                    king_vision_vector[i + 42] = x_east_in_range;
                    king_vision_vector[i + 49] = x_west_in_range;

                    white_pawn_vision_vector[i] = x_east_in_range & y_north_in_range;
                    white_pawn_vision_vector[i + 14] = x_west_in_range & y_north_in_range;
                    white_pawn_vision_vector[i + 28] = y_north_in_range;

                    black_pawn_vision_vector[i + 7] = x_east_in_range & y_south_in_range;
                    black_pawn_vision_vector[i + 21] = x_west_in_range & y_south_in_range;
                    black_pawn_vision_vector[i + 35] = y_south_in_range;
                }

                if ((i == 1) & (y == 1)) {
                    white_pawn_vision_vector[i + 28] = y_north_in_range;
                }
                if ((i == 1) & (y == 6)) {
                    black_pawn_vision_vector[i + 35] = y_south_in_range;
                }
            }

            let mut knight_tuple: [[i32; 2]; 8] = [[0; 2]; 8];
            knight_tuple[0] = [x + 2, y + 1];
            knight_tuple[1] = [x + 1, y + 2];
            knight_tuple[2] = [x - 1, y + 2];
            knight_tuple[3] = [x - 2, y + 1];
            knight_tuple[4] = [x + 2, y - 1];
            knight_tuple[5] = [x + 1, y - 2];
            knight_tuple[6] = [x - 1, y - 2];
            knight_tuple[7] = [x - 2, y - 1];

            for i in 0..8 {
                let t = knight_tuple[i];
                if ((t[0] < 8) & (t[1] < 8) & (t[0] >= 0) & (t[1] >= 0)) {
                    knight_vision_vector[56 + i] = true;
                }
            }

            let queen = encode_bits_into_field(queen_vision_vector);
            let king = encode_bits_into_field(king_vision_vector);
            let knight = encode_bits_into_field(knight_vision_vector);
            let white_pawn = encode_bits_into_field(white_pawn_vision_vector);
            let bishop = encode_bits_into_field(bishop_vision_vector);
            let black_pawn = encode_bits_into_field(black_pawn_vision_vector);
            let rook = encode_bits_into_field(rook_vision_vector);

            r[(64 * (Pieces::WHITE_PAWN - 1)) + (x as Field) + (y as Field * 8)] = white_pawn;
            r[(64 * (Pieces::BLACK_PAWN - 1)) + (x as Field) + (y as Field * 8)] = black_pawn;
            r[(64 * (Pieces::QUEEN - 1)) + (x as Field) + (y as Field * 8)] = queen;
            r[(64 * (Pieces::KING - 1)) + (x as Field) + (y as Field * 8)] = king;
            r[(64 * (Pieces::ROOK - 1)) + (x as Field) + (y as Field * 8)] = rook;
            r[(64 * (Pieces::BISHOP - 1)) + (x as Field) + (y as Field * 8)] = bishop;
            r[(64 * (Pieces::KNIGHT - 1)) + (x as Field) + (y as Field * 8)] = knight;
        }
    }
    r
}

struct PieceData {
    exists: bool,
    id: Field,
    x: Field,
    y: Field,
}
impl std::default::Default for PieceData {
    fn default() -> Self {
        PieceData { exists: false, id: 0, x: 0, y: 0 }
    }
}
fn get_piece_data(pieces: [Piece; 64], player_id: Field) -> [PieceData; 16] {
    let mut r: [PieceData; 16] = [PieceData { exists: false, id: 0, x: 0, y: 0 }; 16];
    let mut idx: Field = 0;
    for i in 0..64 {
        if ((pieces[i].id != Pieces::EMPTY_SQUARE) & (pieces[i].player_id == player_id)) {
            r[idx] = PieceData {
                exists: true,
                id: pieces[i].id,
                x: (i % 8) as Field,
                y: (i / 8) as Field,
            };
            idx += 1;
        }
    }
    r
}

#[test]
fn test_update_vision() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::WHITE_PAWN;

    let vision = update_vision(state, WHITE_PLAYER_ID);

    let expected: [Field; 64] = [
        1, 0, 0, 0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0,
    ];

    assert_eq(vision, expected);
}
#[test]
fn test_update_white_vision2() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[1].id = Pieces::KNIGHT;
    state[2].id = Pieces::BISHOP;
    state[3].id = Pieces::QUEEN;
    state[4].id = Pieces::KING;
    state[5].id = Pieces::BISHOP;
    state[6].id = Pieces::KNIGHT;
    state[7].id = Pieces::ROOK;
    state[8].id = Pieces::WHITE_PAWN;
    state[9].id = Pieces::WHITE_PAWN;
    state[10].id = Pieces::WHITE_PAWN;
    state[11].id = Pieces::WHITE_PAWN;
    state[12].id = Pieces::WHITE_PAWN;
    state[13].id = Pieces::WHITE_PAWN;
    state[14].id = Pieces::WHITE_PAWN;
    state[15].id = Pieces::WHITE_PAWN;

    let vision = update_vision(state, WHITE_PLAYER_ID);

    let expected: [Field; 64] = [
        1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
        1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0,
    ];

    assert_eq(vision, expected);
}

#[test]
fn test_update_white_vision3() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    // state[0].id = Pieces::ROOK;
    // state[1].id = Pieces::KNIGHT;
    // state[2].id = Pieces::BISHOP;
    // state[3].id = Pieces::QUEEN;
    // state[4].id = Pieces::KING;
    // state[5].id = Pieces::BISHOP;
    // state[6].id = Pieces::KNIGHT;
    // state[7].id = Pieces::ROOK;
    // state[8].id = Pieces::WHITE_PAWN;
    // state[9].id = Pieces::WHITE_PAWN;
    // state[10].id = Pieces::WHITE_PAWN;
    // state[11].id = Pieces::WHITE_PAWN;
    // state[12].id = Pieces::WHITE_PAWN;
    // state[13].id = Pieces::WHITE_PAWN;
    // state[14].id = Pieces::WHITE_PAWN;
    // state[15].id = Pieces::WHITE_PAWN;

    state[27].id = Pieces::QUEEN;
    state[35].id = Pieces::ROOK;
    state[35].player_id = BLACK_PLAYER_ID;
    let vision = update_vision(state, WHITE_PLAYER_ID);

    // noir-fmt:ignore
    let expected: [Field; 64] = [
        1,0,0,1,0,0,1,0,
        0,1,0,1,0,1,0,0,
        0,0,1,1,1,0,0,0,
        1,1,1,1,1,1,1,1,
        0,0,1,1,1,0,0,0,
        0,1,0,0,0,1,0,0,
        1,0,0,0,0,0,1,0,
        0,0,0,0,0,0,0,1,
    ];

    // noir-fmt:ignore
    /*
    VISION = [0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00,
              0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01]    */
    assert_eq(vision, expected);
}

#[test]
fn test_update_vision4() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];

    state[35].id = Pieces::KNIGHT;
    let vision = update_vision(state, WHITE_PLAYER_ID);

    // noir-fmt:ignore
    let expected: [Field; 64] = [
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,1,0,1,0,0,0,
        0,1,0,0,0,1,0,0,
        0,0,0,1,0,0,0,0,
        0,1,0,0,0,1,0,0,
        0,0,1,0,1,0,0,0,
        0,0,0,0,0,0,0,0,
    ];

    println(f"vision = {vision}");
    println(f"expected = {expected}");
    assert_eq(vision, expected);
}

#[test]
fn test_update_vision_king() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];

    state[35].id = Pieces::KING;
    let vision = update_vision(state, WHITE_PLAYER_ID);

    // noir-fmt:ignore
    let expected: [Field; 64] = [
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,1,1,1,0,0,0,
        0,0,1,1,1,0,0,0,
        0,0,1,1,1,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
    ];

    println(f"vision = {vision}");
    println(f"expected = {expected}");
    assert_eq(vision, expected);

    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];

    state[4].id = Pieces::KING;
    let vision = update_vision(state, WHITE_PLAYER_ID);

    // noir-fmt:ignore
    let expected: [Field; 64] = [
        0,0,0,1,1,1,0,0,
        0,0,0,1,1,1,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
    ];

    println(f"vision = {vision}");
    println(f"expected = {expected}");
    assert_eq(vision, expected);
}

fn update_vision(pieces: [Piece; 64], player_id: Field) -> [Field; 64] {
    let piece_data: [PieceData; 16] = get_piece_data(pieces, player_id);

    let mut vision: [Field; 64] = [0; 64];

    for i in 0..16 {
        vision = update_vision_for_piece(vision, pieces, piece_data[i]);
    }
    vision
}

fn update_vision_for_piece(
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

    if (piece_data.exists) {
        output_vision[x + (y * 8)] = 1;
    }
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
    // south west
    for i in 0..7 {
        let location: Field = (x + i as Field + 1) + ((y - i as Field - 1) * 8);
        let location_valid = vision_vector[i + 7];

        let bounded_location = location * location_valid as Field;

        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[1] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[1] = true;
            }
        }
    }

    // north east
    for i in 0..7 {
        let location: Field = (x - i as Field - 1) + ((y + i as Field + 1) * 8);
        let location_valid = vision_vector[i + 14];

        let bounded_location = location * location_valid as Field;
        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[2] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[2] = true;
            }
        }
    }

    // south east
    for i in 0..7 {
        let location: Field = (x - i as Field - 1) + ((y - i as Field - 1) * 8);
        let location_valid = vision_vector[i + 21];

        let bounded_location = location * location_valid as Field;
        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[3] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[3] = true;
            }
        }
    }

    // north
    for i in 0..7 {
        let location: Field = (x as Field) + ((y + i as Field + 1) * 8);
        let location_valid = vision_vector[i + 28];

        let bounded_location = location * location_valid as Field;

        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[4] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[4] = true;
            }
        }
    }

    // south
    for i in 0..7 {
        let location: Field = (x as Field) + (y - i as Field - 1) * 8;
        let location_valid = vision_vector[i + 35];

        let bounded_location = location * location_valid as Field;

        let bounded_location = location * location_valid as Field;
        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[5] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[5] = true;
            }
        }
    }

    // east
    for i in 0..7 {
        let location: Field = (x + i as Field + 1) + (y * 8);
        let location_valid = vision_vector[i + 42];

        let bounded_location = location * location_valid as Field;
        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[6] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[6] = true;
            }
        }
    }

    // west
    for i in 0..7 {
        let location: Field = (x - i as Field - 1) + (y * 8);
        let location_valid = vision_vector[i + 49];

        let bounded_location = location * location_valid as Field;
        let square_empty = pieces[bounded_location].id == Pieces::EMPTY_SQUARE;

        if ((location_valid == 1) & !vision_blocked[7] & piece_data.exists) {
            output_vision[bounded_location] = 1;
            if (!square_empty) {
                vision_blocked[7] = true;
            }
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
        if (
            (knight_locations_valid[i] == 1) & piece_data.exists & (piece_data.id == Pieces::KNIGHT)
        ) {
            output_vision[knight_locations[i]] = 1;
        }
    }

    output_vision
}
use std::hash::poseidon2::Poseidon2::hash as poseidon2;

struct Piece {
    id: Field,
    player_id: Field,
    has_moved: Field,
}

impl std::default::Default for Piece {
    fn default() -> Self {
        Piece { id: Pieces::EMPTY_SQUARE, player_id: 0, has_moved: 0 }
    }
}
impl Piece {
    fn encode(self) -> Field {
        (self.id) + (self.player_id * 0x100) + (self.has_moved * 0x10000)
    }

    fn decode(encoded: Field) -> Self {
        let bytes: [u8; 3] = encoded.to_le_bytes();
        Piece { id: bytes[0] as Field, player_id: bytes[1] as Field, has_moved: bytes[2] as Field }
    }
}
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
}

pub struct MoveData {
    x1: Field,
    y1: Field,
    x2: Field,
    y2: Field,
}

pub struct UserState {
    encrypt_secret: Field,
    mask_secret: Field,
    visible_squares: [Field; 64],
    game_state: [Piece; 64],
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

    fn initialize(self, player_id: Field) -> Self {
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

fn validate_move_and_update_board_state(
    board_state: [Piece; 64],
    starting_piece: PieceData,
    ending_piece: PieceData,
    player_id: Field,
) -> [Piece; 64] {
    let mut result: [Piece; 64] = board_state;
    //   let mut result: AdditionalMoveData = AdditionalMoveData::default();
    let vision: [Field; 64] = [0; 64];
    let vision = update_vision_for_piece(vision, board_state, starting_piece);

    assert((player_id == BLACK_PLAYER_ID) | (player_id == WHITE_PLAYER_ID));
    // can the starting piece see the square we want to move to?
    let end_location = ending_piece.y * 8 + ending_piece.x;
    let can_see_square = vision[end_location] == 1;
    let square_can_be_moved_into = (board_state[end_location].id == Pieces::EMPTY_SQUARE)
        | (board_state[end_location].player_id != player_id);

    let mut is_white_promotion = (ending_piece.y == 7)
        & (starting_piece.id == Pieces::WHITE_PAWN)
        & (
            (ending_piece.id != Pieces::WHITE_PAWN)
                | (ending_piece.id != Pieces::BLACK_PAWN)
                | (ending_piece.id != Pieces::EMPTY_SQUARE)
        );
    let mut is_black_promotion = (ending_piece.y == 0)
        & (starting_piece.id == Pieces::BLACK_PAWN)
        & (
            (ending_piece.id != Pieces::WHITE_PAWN)
                | (ending_piece.id != Pieces::BLACK_PAWN)
                | (ending_piece.id != Pieces::EMPTY_SQUARE)
        );
    let mut is_promotion = (is_white_promotion & (player_id == WHITE_PLAYER_ID))
        | (is_black_promotion & (player_id == BLACK_PLAYER_ID));
    assert((starting_piece.id == ending_piece.id) | is_promotion);
    assert(starting_piece.id != Pieces::EMPTY_SQUARE);
    if (player_id == WHITE_PLAYER_ID) {
        assert(starting_piece.id != Pieces::BLACK_PAWN);
    } else {
        assert(starting_piece.id != Pieces::WHITE_PAWN);
    }
    let move_valid_if_not_pawn_or_castle =
        can_see_square & square_can_be_moved_into & (starting_piece.id != Pieces::WHITE_PAWN);

    let mut pawn_valid = false;
    // black
    {
        let en_passant_y: bool = ending_piece.y == starting_piece.y - 1; // ??
        let en_passant_x =
            (ending_piece.x - starting_piece.x) * (ending_piece.x - starting_piece.x) == 1;
        let en_passant_piece_x1 = starting_piece.y * 8 + starting_piece.x - 1;
        let en_passant_piece_x1_valid = starting_piece.x != 0;
        let en_passant_piece_x2_valid = starting_piece.x != 7;

        let en_passant_piece_x2 = starting_piece.y * 8 + starting_piece.x + 1;
        let en_passant_piece_1 = (
            board_state[en_passant_piece_x1 * en_passant_piece_x1_valid as Field].id
                == Pieces::WHITE_PAWN
        )
            & (en_passant_piece_x1_valid);
        let en_passant_piece_2 = (
            board_state[en_passant_piece_x2 * en_passant_piece_x2_valid as Field].id
                == Pieces::WHITE_PAWN
        )
            & (en_passant_piece_x2_valid);
        let en_passant_correct_row = starting_piece.y == 5;
        let en_passant_piece = en_passant_piece_1 | en_passant_piece_2;
        let is_pawn = starting_piece.id == Pieces::BLACK_PAWN;
        let en_passant_valid =
            en_passant_x & en_passant_y & en_passant_piece & en_passant_correct_row & is_pawn;

        let pawn_capture_y = en_passant_y;
        let pawn_capture_x = en_passant_x;
        let pawn_capture_piece = (board_state[end_location].player_id == WHITE_PLAYER_ID)
            & (board_state[end_location].id != Pieces::EMPTY_SQUARE);
        let pawn_capture_valid = pawn_capture_y & pawn_capture_x & pawn_capture_piece & is_pawn;

        let pawn_move_y =
            en_passant_y | ((ending_piece.y - starting_piece.y) == 2) & (starting_piece.y == 6);
        let pawn_move_x = starting_piece.x == ending_piece.x;
        let pawn_move_piece = (board_state[end_location].id == Pieces::EMPTY_SQUARE);
        let pawn_move_valid = pawn_move_y & pawn_move_x & pawn_move_piece & is_pawn;

        let black_pawn_valid = en_passant_valid | pawn_capture_valid | pawn_move_valid;

        if (player_id == BLACK_PLAYER_ID) {
            pawn_valid = black_pawn_valid;
        }

        if (en_passant_valid & (player_id == BLACK_PLAYER_ID)) {
            if (en_passant_piece_1) {
                result[starting_piece.y * 8 + starting_piece.x - 1] = Piece::default();
            }
            if (en_passant_piece_2) {
                result[starting_piece.y * 8 + starting_piece.x + 1] = Piece::default();
            }
        }
    }

    // white
    {
        let en_passant_y: bool = ending_piece.y == starting_piece.y + 1; // ??
        let en_passant_x =
            (ending_piece.x - starting_piece.x) * (ending_piece.x - starting_piece.x) == 1;
        let en_passant_piece_x1 = starting_piece.y * 8 + starting_piece.x - 1;
        let en_passant_piece_x1_valid = starting_piece.x != 0;
        let en_passant_piece_x2_valid = starting_piece.x != 7;

        let en_passant_piece_x2 = starting_piece.y * 8 + starting_piece.x + 1;
        let en_passant_piece_1 = (
            board_state[en_passant_piece_x1 * en_passant_piece_x1_valid as Field].id
                == Pieces::BLACK_PAWN
        )
            & (en_passant_piece_x1_valid);
        let en_passant_piece_2 = (
            board_state[en_passant_piece_x2 * en_passant_piece_x2_valid as Field].id
                == Pieces::BLACK_PAWN
        )
            & (en_passant_piece_x2_valid);
        let en_passant_correct_row = starting_piece.y == 4;
        let en_passant_piece = en_passant_piece_1 | en_passant_piece_2;
        let is_pawn = starting_piece.id == Pieces::WHITE_PAWN;
        let en_passant_valid =
            en_passant_x & en_passant_y & en_passant_piece & en_passant_correct_row & is_pawn;

        let pawn_capture_y = en_passant_y;
        let pawn_capture_x = en_passant_x;
        let pawn_capture_piece = (board_state[end_location].player_id == BLACK_PLAYER_ID)
            & (board_state[end_location].id != Pieces::EMPTY_SQUARE);
        let pawn_capture_valid = pawn_capture_y & pawn_capture_x & pawn_capture_piece & is_pawn;

        let pawn_move_y =
            en_passant_y | ((ending_piece.y - starting_piece.y) == 2) & (starting_piece.y == 1);
        let pawn_move_x = starting_piece.x == ending_piece.x;
        let pawn_move_piece = (board_state[end_location].id == Pieces::EMPTY_SQUARE);
        let pawn_move_valid = pawn_move_y & pawn_move_x & pawn_move_piece & is_pawn;

        let white_pawn_valid = en_passant_valid | pawn_capture_valid | pawn_move_valid;
        if (player_id == WHITE_PLAYER_ID) {
            pawn_valid = white_pawn_valid;
        }

        if (en_passant_valid & (player_id == WHITE_PLAYER_ID)) {
            if (en_passant_piece_1) {
                result[starting_piece.y * 8 + starting_piece.x - 1] = Piece::default();
            }
            if (en_passant_piece_2) {
                result[starting_piece.y * 8 + starting_piece.x + 1] = Piece::default();
            }
        }
    }
    let castle_is_king = starting_piece.id == Pieces::KING;
    let castle_king_not_moved = board_state[starting_piece.y * 8 + starting_piece.x].has_moved == 0;

    let castle_left = ending_piece.x == starting_piece.x - 2;
    let castle_right = ending_piece.y == starting_piece.x + 2;
    let castle_y = ending_piece.y == starting_piece.y;

    let white_rook_present_left =
        (board_state[0].id == Pieces::ROOK) & (board_state[0].has_moved == 0);
    let white_rook_present_right =
        (board_state[7].id == Pieces::ROOK) & (board_state[7].has_moved == 0);

    let white_rook_condition_met =
        (castle_left & white_rook_present_left) | (castle_right & white_rook_present_right);

    let black_rook_present_left =
        (board_state[56].id == Pieces::ROOK) & (board_state[56].has_moved == 0);
    let black_rook_present_right =
        (board_state[63].id == Pieces::ROOK) & (board_state[63].has_moved == 0);

    let black_rook_condition_met =
        (castle_left & black_rook_present_left) | (castle_right & black_rook_present_right);

    let rook_condition_met = (white_rook_condition_met & (player_id == WHITE_PLAYER_ID))
        | (black_rook_condition_met & (player_id == BLACK_PLAYER_ID));
    let first_empty_square_x = starting_piece.x + castle_right as Field - castle_left as Field;
    let second_empty_square_x =
        starting_piece.x + (2 * castle_right as Field) - (2 * castle_left as Field);

    let mut y_offset = 0;
    if (player_id == BLACK_PLAYER_ID) {
        y_offset = 56;
    }
    let first_empty_square_met: bool =
        board_state[first_empty_square_x + y_offset].id == Pieces::EMPTY_SQUARE;
    let second_empty_square_met: bool =
        board_state[second_empty_square_x + y_offset].id == Pieces::EMPTY_SQUARE;
    let rook_empty_square_met =
        ((board_state[1 + y_offset].id == Pieces::EMPTY_SQUARE) & castle_left) | castle_right;
    let castle_empty_square_check =
        first_empty_square_met & second_empty_square_met & rook_empty_square_met;

    let castle_valid = castle_is_king
        & castle_king_not_moved
        & castle_y
        & rook_condition_met
        & castle_empty_square_check;
    let valid_move = move_valid_if_not_pawn_or_castle | pawn_valid | castle_valid;

    // need to move the rook
    if (castle_valid) {
        if (castle_left) {
            let mut moved_rook = result[y_offset * 8];
            moved_rook.has_moved = 1;
            result[y_offset * 8] = Piece::default();
            result[3 + y_offset * 8] = moved_rook;
        }
        if (castle_right) {
            let mut moved_rook = result[y_offset * 8 + 7];
            moved_rook.has_moved = 1;
            result[y_offset * 8 + 7] = Piece::default();
            result[5 + y_offset * 8] = moved_rook;
        }
    }

    let mut moved_piece = result[starting_piece.y * 8 + starting_piece.x];
    moved_piece.has_moved = 1;
    result[starting_piece.y * 8 + starting_piece.x] = Piece::default();
    result[ending_piece.y * 8 + ending_piece.x] = moved_piece;
    assert_eq(valid_move, true);

    result
}

fn consume_opponent_move_and_update_game_state(
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
        if (opponent_output_state[0][i].is_some()) {
            let decoded = Piece::decode(opponent_output_state[0][i].unwrap_unchecked());
            if (decoded.id != Pieces::EMPTY_SQUARE) {
                new_state.game_state[i] = decoded;
            }
        }
    }

    new_state
}

#[test]
fn test_validate_white_move() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[1].id = Pieces::KNIGHT;
    state[2].id = Pieces::BISHOP;
    state[3].id = Pieces::QUEEN;
    state[4].id = Pieces::KING;
    state[5].id = Pieces::BISHOP;
    state[6].id = Pieces::KNIGHT;
    state[7].id = Pieces::ROOK;
    state[8].id = Pieces::WHITE_PAWN;
    state[9].id = Pieces::WHITE_PAWN;
    state[10].id = Pieces::WHITE_PAWN;
    state[11].id = Pieces::WHITE_PAWN;
    state[12].id = Pieces::WHITE_PAWN;
    state[13].id = Pieces::WHITE_PAWN;
    state[14].id = Pieces::WHITE_PAWN;
    state[15].id = Pieces::WHITE_PAWN;

    let starting_piece = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 4, y: 1 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 4, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 4, y: 3 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);

    let starting_piece = PieceData { exists: true, id: Pieces::KNIGHT, x: 1, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KNIGHT, x: 2, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KNIGHT, x: 0, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let starting_piece = PieceData { exists: true, id: Pieces::KNIGHT, x: 6, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KNIGHT, x: 7, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KNIGHT, x: 5, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test]
fn test_validate_white_pawn_move_and_capture() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[35].id = Pieces::WHITE_PAWN;
    state[42].id = Pieces::BLACK_PAWN;
    state[42].player_id = BLACK_PLAYER_ID;

    let starting_piece = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 3, y: 4 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 2, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 3, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);

    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];

    // en passant
    state[35].id = Pieces::BLACK_PAWN;
    state[35].player_id = BLACK_PLAYER_ID;
    state[36].id = Pieces::WHITE_PAWN;
    let starting_piece = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 4, y: 4 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 3, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_validate_white_pawn_cannot_move_diagonally_if_not_capture() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[35].id = Pieces::WHITE_PAWN;

    let starting_piece = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 3, y: 4 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 2, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_validate_white_pawn_cannot_en_passant_on_wrong_row() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];

    state[27].id = Pieces::BLACK_PAWN;
    state[27].player_id = BLACK_PLAYER_ID;
    state[28].id = Pieces::WHITE_PAWN;
    let starting_piece = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 4, y: 3 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::WHITE_PAWN, x: 3, y: 4 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_validate_white_move_blocked() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[1].id = Pieces::KNIGHT;
    state[2].id = Pieces::BISHOP;
    state[3].id = Pieces::QUEEN;
    state[4].id = Pieces::KING;
    state[5].id = Pieces::BISHOP;
    state[6].id = Pieces::KNIGHT;
    state[7].id = Pieces::ROOK;
    state[8].id = Pieces::WHITE_PAWN;
    state[9].id = Pieces::WHITE_PAWN;
    state[10].id = Pieces::WHITE_PAWN;
    state[11].id = Pieces::WHITE_PAWN;
    state[12].id = Pieces::WHITE_PAWN;
    state[13].id = Pieces::WHITE_PAWN;
    state[14].id = Pieces::WHITE_PAWN;
    state[15].id = Pieces::WHITE_PAWN;

    let starting_piece = PieceData { exists: true, id: Pieces::KING, x: 5, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KING, x: 5, y: 1 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test]
fn test_validate_white_castle() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[4].id = Pieces::KING;

    let starting_piece = PieceData { exists: true, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KING, x: 2, y: 0 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_white_castle_fails_if_blocked() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[1].id = Pieces::WHITE_PAWN;
    state[4].id = Pieces::KING;

    let starting_piece = PieceData { exists: true, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KING, x: 2, y: 0 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_white_castle_fails_if_rook_already_moved() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[0].has_moved = 1;
    state[4].id = Pieces::KING;

    let starting_piece = PieceData { exists: true, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KING, x: 2, y: 0 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_white_castle_fails_if_king_already_moved() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[4].id = Pieces::KING;
    state[4].has_moved = 1;

    let starting_piece = PieceData { exists: true, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: true, id: Pieces::KING, x: 2, y: 0 };

    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

unconstrained fn __div2(input: Field) -> u32 {
    let r = input as u32;
    r / 2
}

pub fn move(
    input_state: GameState,
    user_state: UserState,
    move_data: MoveData,
    player_id: Field,
) -> (GameState, UserState, Field, Field) {
    assert((player_id == WHITE_PLAYER_ID) | (player_id == BLACK_PLAYER_ID));
    assert_eq(input_state.game_ended, false);
    // Safety: cheapish check to see if player_id is correct. If move_count = even, white's turn. odd = black's turn
    let move_count_div2 = unsafe { __div2(input_state.move_count) };
    assert_eq(move_count_div2 as Field * 2 + player_id, input_state.move_count);
    let uu = input_state.move_count;
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
        PieceData { id: starting_piece.id, x: move_data.x1, y: move_data.y1, exists: true };
    let ending_piece_data: PieceData =
        PieceData { id: starting_piece.id, x: move_data.x2, y: move_data.y2, exists: true };

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

    (output_state, user_state, output_state.hash(), user_state.hash())
    // need to validate move.
    // if Castle, or En Passant, 2 states need to be updated

    // White has received Black's mask commitments (what black wants to see from white)
}

#[test]
fn test_move() {
    let mut game_state: GameState = GameState::default();
    let mut alice_state: UserState = UserState::default();
    let mut bob_state: UserState = UserState::default();

    alice_state.encrypt_secret = poseidon2([1], 1);
    alice_state.mask_secret = poseidon2([2], 1);
    bob_state.encrypt_secret = poseidon2([3], 1);
    bob_state.mask_secret = poseidon2([4], 1);

    // TODO find a nicer way of doing this
    let user_encrypt_secret_hashes = [
        poseidon2([alice_state.encrypt_secret, -1], 2),
        poseidon2([bob_state.encrypt_secret, -1], 2),
    ];
    let user_mask_secret_hashes =
        [poseidon2([alice_state.mask_secret, -1], 2), poseidon2([bob_state.mask_secret, -1], 2)];
    game_state.mpc_state.user_encrypt_secret_hashes = user_encrypt_secret_hashes;
    game_state.mpc_state.user_mask_secret_hashes = user_mask_secret_hashes;

    // alice moves pawn

    let alice_move: MoveData = MoveData { x1: 4, y1: 1, x2: 4, y2: 3 };
    let m = move(game_state, alice_state, alice_move, WHITE_PLAYER_ID);
    game_state = m.0;

    let ff = m.1.game_state;
    let alice_state2 = m.1;

    // bob updates her state after receiving alice's move output
    // let mut bob_state =
    //     consume_opponent_move_and_update_game_state(game_state, bob_state, BLACK_PLAYER_ID);

    let bob_move: MoveData = MoveData { x1: 4, y1: 6, x2: 4, y2: 4 };
    let m = move(game_state, bob_state, bob_move, BLACK_PLAYER_ID);
    game_state = m.0;
    bob_state = m.1;
    // // alice updates her state after receiving bob's move output
    // let alice_state =
    //     consume_opponent_move_and_update_game_state(game_state, alice_state, WHITE_PLAYER_ID);

    // alice moves queen to H5
    let alice_move = MoveData { x1: 3, y1: 0, x2: 7, y2: 4 };
    let m = move(game_state, alice_state2, alice_move, WHITE_PLAYER_ID);
    game_state = m.0;
    alice_state = m.1;
    // // bob updates her state after receiving alice's move output
    // let bob_state =
    //     consume_opponent_move_and_update_game_state(game_state, bob_state, BLACK_PLAYER_ID);

    // bob moves pawn to F5
    let bob_move = MoveData { x1: 5, y1: 6, x2: 5, y2: 5 };
    let m = move(game_state, bob_state, bob_move, BLACK_PLAYER_ID);
    game_state = m.0;
    bob_state = m.1;
    // alice moves queen to E8, checkmate
    let alice_move = MoveData { x1: 7, y1: 4, x2: 4, y2: 7 };
    let m = move(game_state, alice_state, alice_move, WHITE_PLAYER_ID);
    game_state = m.0;
    alice_state = m.1;
    assert_eq(game_state.game_ended, true);
    // // alice updates her state after receiving bob's move output
    // let alice_state =
    //     consume_opponent_move_and_update_game_state(game_state, alice_state, WHITE_PLAYER_ID);

}
/*

Ok so we want to make a chess app....

players Alice and Bob

how do we represent game state?

we have a Piece struct
and an array of 64 Piece objects


*/
fn execute_round_foo() {
    let alice_secret = std::hash::poseidon2::Poseidon2::hash([0], 1);
    let alice_mask = std::hash::poseidon2::Poseidon2::hash([1], 1);
    let bob_secret = std::hash::poseidon2::Poseidon2::hash([2], 1);
    let bob_mask = std::hash::poseidon2::Poseidon2::hash([3], 1);

    let round_state: RoundState<4, 2> = RoundState {
        round_number: 1,
        user_encrypt_secret_hashes: [
            poseidon2([alice_secret, -1], 2),
            poseidon2([bob_secret, -1], 2),
        ],
        user_mask_secret_hashes: [poseidon2([alice_mask, -1], 2), poseidon2([bob_mask, -1], 2)],
        previous_output_states: [UserOutputState::default(); 2],
    };

    let previous_round_hash = round_state.hash();
    let alice_state = [0, 1, 2, 3];
    let alice_reveal = [0, 1, 0, 1];
    let bob_state = [-1, -2, -3, -4];
    let bob_reveal = [1, 0, 1, 0];

    // after executing. we have ciphertexts and mask commitments, but no mask reveal commitments
    let alice_output = execute_round(
        alice_state,
        alice_reveal,
        alice_secret,
        alice_mask,
        round_state,
        previous_round_hash,
        0,
    );

    let round_state = round_state.update([alice_output.0, round_state.previous_output_states[1]]);
    let previous_round_hash = round_state.hash();

    let bob_output = execute_round(
        bob_state,
        bob_reveal,
        bob_secret,
        bob_mask,
        round_state,
        previous_round_hash,
        1,
    );

    let round_state = round_state.update([round_state.previous_output_states[0], bob_output.0]);
    let previous_round_hash = round_state.hash();

    let alice_output = execute_round(
        alice_state,
        alice_reveal,
        alice_secret,
        alice_mask,
        round_state,
        previous_round_hash,
        0,
    );

    let round_state = round_state.update([alice_output.0, round_state.previous_output_states[1]]);
    let previous_round_hash = round_state.hash();

    let bob_output = execute_round(
        bob_state,
        bob_reveal,
        bob_secret,
        bob_mask,
        round_state,
        previous_round_hash,
        1,
    );

    let alice_decrypted = alice_output.1[0];
    let bob_decrypted = bob_output.1[0];

    assert_eq(alice_decrypted[0].is_some(), false);
    assert_eq(alice_decrypted[1].is_some(), true);
    assert_eq(alice_decrypted[2].is_some(), false);
    assert_eq(alice_decrypted[3].is_some(), true);

    assert_eq(alice_decrypted[1].unwrap_unchecked(), -2);
    assert_eq(alice_decrypted[3].unwrap_unchecked(), -4);

    assert_eq(bob_decrypted[0].is_some(), true);
    assert_eq(bob_decrypted[1].is_some(), false);
    assert_eq(bob_decrypted[2].is_some(), true);
    assert_eq(bob_decrypted[3].is_some(), false);

    assert_eq(bob_decrypted[0].unwrap_unchecked(), 0);
    assert_eq(bob_decrypted[2].unwrap_unchecked(), 2);
}

// NEXT STEPS TURN INTO LIBRARY AND BENCHMARKKKKKKKKK
