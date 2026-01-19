use crate::{BLACK_PLAYER_ID, WHITE_PLAYER_ID};
use crate::piece::{Piece, PieceData, Pieces};
use crate::update_vision::update_vision_for_piece;

pub fn validate_move_and_update_board_state(
    board_state: [Piece; 64],
    starting_piece: PieceData,
    ending_piece: PieceData,
    player_id: Field,
) -> [Piece; 64] {
    let mut result: [Piece; 64] = board_state;
    let mut vision: [Field; 64] = [0; 64];
    update_vision_for_piece(&mut vision, board_state, starting_piece);

    assert((player_id == BLACK_PLAYER_ID) | (player_id == WHITE_PLAYER_ID));
    // can the starting piece see the square we want to move to?
    let end_location_f = ending_piece.y * 8 + ending_piece.x;
    end_location_f.assert_max_bit_size::<32>();
    let end_location = end_location_f as u32;
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

    let piece_location = starting_piece.y * 8 + starting_piece.x;
    let left_piece = starting_piece.y * 8 + starting_piece.x - 1;
    let right_piece = starting_piece.y * 8 + starting_piece.x + 1;
    left_piece.assert_max_bit_size::<32>();
    right_piece.assert_max_bit_size::<32>();
    piece_location.assert_max_bit_size::<32>();
    // black
    {
        let en_passant_y: bool = ending_piece.y == starting_piece.y - 1; // ??
        let en_passant_x =
            (ending_piece.x - starting_piece.x) * (ending_piece.x - starting_piece.x) == 1;
        let en_passant_piece_x1_valid = starting_piece.x != 0;
        let en_passant_piece_x2_valid = starting_piece.x != 7;


        let b_idx = left_piece * en_passant_piece_x1_valid as Field;
        let b_idx2 = right_piece * en_passant_piece_x2_valid as Field;
        b_idx.assert_max_bit_size::<32>();
        b_idx2.assert_max_bit_size::<32>();
        let en_passant_piece_1 = (
            board_state[b_idx as u32].id
                == Pieces::WHITE_PAWN
        )
            & (en_passant_piece_x1_valid);
        let en_passant_piece_2 = (
            board_state[b_idx2 as u32].id
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
                result[left_piece as u32] = Piece::default();
            }
            if (en_passant_piece_2) {
                result[right_piece as u32] = Piece::default();
            }
        }
    }

    // white
    {
        let en_passant_y: bool = ending_piece.y == starting_piece.y + 1; // ??
        let en_passant_x =
            (ending_piece.x - starting_piece.x) * (ending_piece.x - starting_piece.x) == 1;
        let en_passant_piece_x1_valid = starting_piece.x != 0;
        let en_passant_piece_x2_valid = starting_piece.x != 7;
        let b_idx = left_piece * en_passant_piece_x1_valid as Field;
        b_idx.assert_max_bit_size::<32>();
        let b_idx2 = right_piece * en_passant_piece_x2_valid as Field;
        b_idx2.assert_max_bit_size::<32>();
        let en_passant_piece_1 = (
            board_state[b_idx as u32].id
                == Pieces::BLACK_PAWN
        )
            & (en_passant_piece_x1_valid);
        let en_passant_piece_2 = (
            board_state[b_idx2 as u32].id
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
                result[left_piece as u32] = Piece::default();
            }
            if (en_passant_piece_2) {
                result[right_piece as u32] = Piece::default();
            }
        }
    }
    let castle_is_king = starting_piece.id == Pieces::KING;
    let castle_king_not_moved = board_state[piece_location as u32].has_moved == 0;

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

    let b_idx: Field = first_empty_square_x + y_offset;
    let b_idx2 = second_empty_square_x + y_offset;
    let b_idx3 = 1 + y_offset;
    b_idx.assert_max_bit_size::<32>();
    b_idx2.assert_max_bit_size::<32>();
    b_idx3.assert_max_bit_size::<32>();

    let first_empty_square_met: bool =
        board_state[b_idx as u32].id == Pieces::EMPTY_SQUARE;
    let second_empty_square_met: bool =
        board_state[b_idx2 as u32].id == Pieces::EMPTY_SQUARE;
    let rook_empty_square_met =
        ((board_state[b_idx3 as u32].id == Pieces::EMPTY_SQUARE) & castle_left) | castle_right;
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
        let b_idx: Field = y_offset * 8;
        let b_idx2 = b_idx + 3;
        let b_idx3 = b_idx + 5;
        let b_idx4 = b_idx + 7;
        b_idx.assert_max_bit_size::<32>();
        b_idx2.assert_max_bit_size::<32>();
        b_idx3.assert_max_bit_size::<32>();
        b_idx4.assert_max_bit_size::<32>();

        if (castle_left) {
            let mut moved_rook = result[b_idx as u32];
            moved_rook.has_moved = 1;
            result[b_idx as u32] = Piece::default();
            result[b_idx2 as u32] = moved_rook;
        }
        if (castle_right) {
            let mut moved_rook = result[b_idx4 as u32];
            moved_rook.has_moved = 1;
            result[b_idx4 as u32] = Piece::default();
            result[b_idx3 as u32] = moved_rook;
        }
    }

    let mut moved_piece = result[piece_location as u32];
    moved_piece.has_moved = 1;
    result[piece_location as u32] = Piece::default();

    let b_idx: Field = ending_piece.y * 8 + ending_piece.x;
    b_idx.assert_max_bit_size::<32>();
    result[b_idx as u32] = moved_piece;
    assert_eq(valid_move, true);

    result
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

    let starting_piece = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 4, y: 1 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 4, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 4, y: 3 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);

    let starting_piece = PieceData { exists: 1, id: Pieces::KNIGHT, x: 1, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KNIGHT, x: 2, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KNIGHT, x: 0, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let starting_piece = PieceData { exists: 1, id: Pieces::KNIGHT, x: 6, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KNIGHT, x: 7, y: 2 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KNIGHT, x: 5, y: 2 };
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

    let starting_piece = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 3, y: 4 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 2, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 3, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);

    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];

    // en passant
    state[35].id = Pieces::BLACK_PAWN;
    state[35].player_id = BLACK_PLAYER_ID;
    state[36].id = Pieces::WHITE_PAWN;
    let starting_piece = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 4, y: 4 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 3, y: 5 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test(should_fail)]
fn test_validate_white_pawn_cannot_move_diagonally_if_not_capture() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[35].id = Pieces::WHITE_PAWN;

    let starting_piece = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 3, y: 4 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 2, y: 5 };
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
    let starting_piece = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 4, y: 3 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::WHITE_PAWN, x: 3, y: 4 };
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

    let starting_piece = PieceData { exists: 1, id: Pieces::KING, x: 5, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KING, x: 5, y: 1 };
    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}

#[test]
fn test_validate_white_castle() {
    let mut state: [Piece; 64] =
        [Piece { id: Pieces::EMPTY_SQUARE, player_id: WHITE_PLAYER_ID, has_moved: 0 }; 64];
    state[0].id = Pieces::ROOK;
    state[4].id = Pieces::KING;

    let starting_piece = PieceData { exists: 1, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KING, x: 2, y: 0 };
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

    let starting_piece = PieceData { exists: 1, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KING, x: 2, y: 0 };
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

    let starting_piece = PieceData { exists: 1, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KING, x: 2, y: 0 };
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

    let starting_piece = PieceData { exists: 1, id: Pieces::KING, x: 4, y: 0 };
    let ending_piece: PieceData = PieceData { exists: 1, id: Pieces::KING, x: 2, y: 0 };

    let _ =
        validate_move_and_update_board_state(state, starting_piece, ending_piece, WHITE_PLAYER_ID);
}
