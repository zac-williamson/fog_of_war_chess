use crate::{BLACK_PLAYER_ID, WHITE_PLAYER_ID};
use crate::piece::{Piece, PieceData, Pieces};
use crate::vision_table::VISION_TABLE;

pub(crate) fn get_piece_data(pieces: [Piece; 64], player_id: Field) -> [PieceData; 16] {
    let mut r: [PieceData; 16] = [PieceData { exists: 0, id: 0, x: 0, y: 0 }; 16];
    let mut idx: Field = 0;

    let mut packed_piece_data: [Field; 17] = [0; 17];

    for i in 0..64 {
        let is_not_empty_square = (pieces[i].id != Pieces::EMPTY_SQUARE) as Field;
        let mut is_player_piece = (pieces[i].player_id - player_id);
        std::as_witness(is_player_piece);
        is_player_piece = 1 - (is_player_piece * is_player_piece);
        std::as_witness(is_player_piece);

        let piece_x = (i % 8) as Field;
        let piece_y = (i / 8) as Field;
        assert_constant(piece_x);
        assert_constant(piece_y);

        let insert_piece = is_not_empty_square * is_player_piece;
        std::as_witness(insert_piece);

        let piece_to_insert =
            PieceData { exists: 1, id: pieces[i].id, x: piece_x, y: piece_y }.pack();

        let input_piece = packed_piece_data[idx];
        let output = input_piece * (1 - insert_piece) + insert_piece * piece_to_insert;
        packed_piece_data[idx] = output;
        idx += insert_piece;
    }

    for i in 0..16 {
        r[i] = PieceData::unpack(packed_piece_data[i]);
    }

    r
}

pub(crate) fn update_vision(pieces: [Piece; 64], player_id: Field) -> [Field; 64] {
    let piece_data: [PieceData; 16] = get_piece_data(pieces, player_id);

    let mut vision: [Field; 64] = [0; 64];

    for i in 0..16 {
        update_vision_for_piece(&mut vision, pieces, piece_data[i]);
    }
    vision
}

pub(crate) fn update_vision_for_piece(
    output_vision: &mut [Field; 64],
    pieces: [Piece; 64],
    piece_data: PieceData,
) {
    let x = piece_data.x;
    let y = piece_data.y;
    let piece_id = piece_data.id - 1;
    let vision_idx = piece_id * 64 + (x as Field) + (y as Field * 8);
    let vision_idx = vision_idx * piece_data.exists as Field;
    let vision_vector_f = VISION_TABLE[vision_idx];
    let vision_vector: [u1; 64] = vision_vector_f.to_le_bits();

    {
        let input_vision = output_vision[x + (y * 8)];
        let updated_vision = (1 - piece_data.exists) * input_vision + piece_data.exists;
        output_vision[x + (y * 8)] = updated_vision;
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
