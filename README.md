# fog_of_war_chess

Fog of war chess library written in Noir

**This library has not been audited and should be used at your own risk!**

## Noir version compatibility

This library is tested to work as of Noir version  1.0.0-beta.3.

## Benchmarks

Benchmarks are ignored by `git` and checked on pull-request. As such, benchmarks may be generated
with the following command.

```bash
# execute the following
./scripts/build-gates-report.sh
```

The benchmark will be generated at `./gates_report.json`.

## Installation

In your _Nargo.toml_ file, add the version of this library you would like to install under dependency:

```toml
[dependencies]
LIBRARY = { tag = "v0.1.1", git = "https://github.com/noir-lang/fog_of_war_chess" }
```

## `library`

## Usage

### Generating Proofs

`pub fn move(
    input_state: GameState,
    user_state: UserState,
    move_data: MoveData,
    player_id: Field,
) -> (GameState, MoveHashes)`

This function generates a proof of a player move. `player_id = 0` is white, `player_id=1` is black. `MoveData` describes which piece is being moved. For castling, the king is the moved piece. En passant is currently in a broken state.

`GameState` stores public information about the game, including the MPC state required for players to transmit move information to each other. `UserState` is a user's private state, that describes their board state and the randomness they are using to encrypt `GameState` data.

Each move must be represented as an independent zero-knowledge proof. A game's transcript can either be the set of all move proofs in the game, or a recursive proof of the move proofs (not currently implemented).

`move` returns the new `GameState` resulting from the move, as well as `MoveHashes` which contains a hash of the initial GameState and UserState, as well as the hash of the final GameState and UserState. These hashes are used to validate continuity between moves. 

### Typescript API

The functions in `api/mod.nr` are designed to be used by out-of-circuit app code to compute game state for both players. Their Typescript versions were generated via `nargo-codegen` and are located at `codegen/index.ts`

`pub fn consume_opponent_move_and_update_game_state(
    input_state: GameState,
    user_state: UserState,
    player_id: Field,
) -> UserState`

After a player has made a move, their opponent calls this function to update their `UserState` - this will reveal any opponent pieces that the player has vision on.

`pub fn update_user_state_from_move(
    is_first_two_moves: bool,
    user_state: UserState,
    move_data: MoveData,
    player_id: Field,
) -> UserState`

After a player has made a move, *they* call this function to update their `UserState` to reflect their move.

`pub fn commit_to_user_secrets(
    game_state: GameState,
    encrypt_secret: Field,
    mask_secret: Field,
    player_id: Field,
) -> GameState`

Each player needs 2 secrets that are used to encrypt MPC game state. This function takes an input `GameState` object and produces an updated `GameState` object that contains encrypted representations of their secrets. This step must be done by both players prior to starting a game.

`empty_game_state`, `empty_white_state`, `empty_black_state` are used to initialize empty `GameState` and `UserState` objects prior to starting a game.

To see how API functions are used, see https://github.com/zac-williamson/fog_of_war_chess_app