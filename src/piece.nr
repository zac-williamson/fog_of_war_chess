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

pub(crate) struct Piece {
    pub(crate) id: Field,
    pub(crate) player_id: Field,
    pub(crate) has_moved: Field,
}
impl std::default::Default for Piece {
    fn default() -> Self {
        Piece { id: Pieces::EMPTY_SQUARE, player_id: 0, has_moved: 0 }
    }
}
impl Piece {
    pub(crate) fn encode(self) -> Field {
        (self.id) + (self.player_id * 0x100) + (self.has_moved * 0x10000)
    }

    pub(crate) fn decode(encoded: Field) -> Self {
        let bytes: [u8; 3] = encoded.to_le_bytes();
        Piece { id: bytes[0] as Field, player_id: bytes[1] as Field, has_moved: bytes[2] as Field }
    }
}

pub(crate) struct PieceData {
    pub(crate) exists: Field,
    pub(crate) id: Field,
    pub(crate) x: Field,
    pub(crate) y: Field,
}
impl std::default::Default for PieceData {
    fn default() -> Self {
        PieceData { exists: 0, id: 0, x: 0, y: 0 }
    }
}
impl PieceData {
    pub(crate) fn pack(self) -> Field {
        self.exists + (self.id * 0x100) + (self.x * 0x10000) + (self.y * 0x1000000)
    }
    pub(crate) fn unpack(packed: Field) -> Self {
        let bytes: [u8; 4] = packed.to_le_bytes();
        PieceData {
            exists: bytes[0] as Field,
            id: bytes[1] as Field,
            x: bytes[2] as Field,
            y: bytes[3] as Field,
        }
    }
}
