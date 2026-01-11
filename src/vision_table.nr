use crate::piece::{Pieces};

pub(crate) comptime global VISION_TABLE: [Field; 448] = get_vision_table();

unconstrained fn encode_bits_into_field(bits: [bool; 64]) -> Field {
    let mut r: Field = 0;
    for i in 0..64 {
        r = r * 2;
        r += bits[63 - i] as Field;
    }
    r
}
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
            knight_tuple[0] = [x as i32 + 2, y as i32 + 1];
            knight_tuple[1] = [x as i32 + 1, y as i32 + 2];
            knight_tuple[2] = [x as i32 - 1, y as i32 + 2];
            knight_tuple[3] = [x as i32 - 2, y as i32 + 1];
            knight_tuple[4] = [x as i32 + 2, y as i32 - 1];
            knight_tuple[5] = [x as i32 + 1, y as i32 - 2];
            knight_tuple[6] = [x as i32 - 1, y as i32 - 2];
            knight_tuple[7] = [x as i32 - 2, y as i32 - 1];

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

            let to_u32 = |x: Field| {
                    x.assert_max_bit_size::<32>();
                    x as u32
            };

            r[to_u32((64 * (Pieces::WHITE_PAWN - 1)) + (x as Field) + (y as Field * 8))] = white_pawn;
            r[to_u32((64 * (Pieces::BLACK_PAWN - 1)) + (x as Field) + (y as Field * 8))] = black_pawn;
            r[to_u32((64 * (Pieces::QUEEN - 1)) + (x as Field) + (y as Field * 8))] = queen;
            r[to_u32((64 * (Pieces::KING - 1)) + (x as Field) + (y as Field * 8))] = king;
            r[to_u32((64 * (Pieces::ROOK - 1)) + (x as Field) + (y as Field * 8))] = rook;
            r[to_u32((64 * (Pieces::BISHOP - 1)) + (x as Field) + (y as Field * 8))] = bishop;
            r[to_u32((64 * (Pieces::KNIGHT - 1)) + (x as Field) + (y as Field * 8))] = knight;
        }
    }
    r
}
