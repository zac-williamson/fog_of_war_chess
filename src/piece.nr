pub mod Pieces {
    pub global EMPTY_SQUARE: Field = 0;
    pub global WHITE_PAWN: Field = 1;
    pub global BLACK_PAWN: Field = 2;
    pub global KNIGHT: Field = 3;
    pub global BISHOP: Field = 4;
    pub global ROOK: Field = 5;
    pub global QUEEN: Field = 6;
    pub global KING: Field = 7;
}

pub struct Piece {
    pub id: Field,
    pub player_id: Field,
    pub has_moved: Field,
}
impl std::default::Default for Piece {
    fn default() -> Self {
        Piece { id: Pieces::EMPTY_SQUARE, player_id: 0, has_moved: 0 }
    }
}
impl Piece {
    pub fn encode(self) -> Field {
        (self.id) + (self.player_id * 0x100) + (self.has_moved * 0x10000)
    }

    pub fn decode(encoded: Field) -> Self {
        let bytes: [u8; 3] = encoded.to_le_bytes();
        Piece { id: bytes[0] as Field, player_id: bytes[1] as Field, has_moved: bytes[2] as Field }
    }
}

pub struct PieceData {
    pub exists: Field,
    pub id: Field,
    pub x: Field,
    pub y: Field,
}
impl std::default::Default for PieceData {
    fn default() -> Self {
        PieceData { exists: 0, id: 0, x: 0, y: 0 }
    }
}
impl PieceData {
    pub fn pack(self) -> Field {
        self.exists + (self.id * 0x100) + (self.x * 0x10000) + (self.y * 0x1000000)
    }
    pub fn unpack(packed: Field) -> Self {
        let bytes: [u8; 4] = packed.to_le_bytes();
        PieceData {
            exists: bytes[0] as Field,
            id: bytes[1] as Field,
            x: bytes[2] as Field,
            y: bytes[3] as Field,
        }
    }
}
