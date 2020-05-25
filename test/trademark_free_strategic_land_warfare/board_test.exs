defmodule TrademarkFreeStrategicLandWarfare.BoardTest do
  use ExUnit.Case

  alias TrademarkFreeStrategicLandWarfare.{Board, Piece}

  def shuffled_pieces() do
    Board.piece_name_counts()
    |> Enum.flat_map(fn {type, count} ->
      for _ <- 1..count, do: type
    end)
    |> Enum.shuffle()
  end

  def good_piece_setup() do
    Enum.chunk_every(shuffled_pieces(), 10)
  end

  def bad_piece_setup() do
    [replace_this, with_this] =
      Board.piece_name_counts()
      |> Map.keys()
      |> Enum.shuffle()
      |> Enum.take(2)

    shuffled_pieces()
    |> Enum.map(fn piece ->
      case piece do
        ^replace_this -> with_this
        piece -> piece
      end
    end)
    |> Enum.chunk_every(4)
  end

  def placements_from_board(board, player) do
    board.rows
    |> Board.maybe_flip(player)
    |> Enum.drop(6)
    |> Enum.map(fn row ->
      Enum.map(row, fn column -> column.name end)
    end)
  end

  describe "piece_name_counts" do
    test "returns a hash with correct piece counts" do
      counts = Board.piece_name_counts()
      assert counts[:marshall] == 1
      assert counts[:miner] == 5
    end
  end

  describe "init_pieces" do
    test "for player 1, no flip necessary" do
      placements = good_piece_setup()
      {:ok, new_board} = Board.init_pieces(Board.new(), placements, 1)
      assert placements_from_board(new_board, 1) == placements
    end

    test "for player 2, flip the board to player perspective before inserting" do
      placements = good_piece_setup()
      {:ok, new_board} = Board.init_pieces(Board.new(), placements, 2)
      assert placements_from_board(new_board, 2) == placements
    end

    test "doesn't mess up previously placed pieces" do
      [player_1_placements, player_2_placements] = for _ <- 1..2, do: good_piece_setup()

      {:ok, board_with_player_1_placements} =
        Board.init_pieces(Board.new(), player_1_placements, 1)

      {:ok, board_with_player_2_placements} =
        Board.init_pieces(board_with_player_1_placements, player_2_placements, 2)

      assert placements_from_board(board_with_player_1_placements, 1) == player_1_placements
      assert placements_from_board(board_with_player_2_placements, 2) == player_2_placements
    end

    test "returns a board with 10 rows" do
      {:ok, new_board} = Board.init_pieces(Board.new(), good_piece_setup(), 2)
      assert length(new_board.rows) == 10
    end

    test "has lake pieces in the correct places" do
      {:ok, new_board} = Board.init_pieces(Board.new(), good_piece_setup(), 2)
      rows = new_board.rows

      for {x, y} <- [{2, 4}, {3, 4}, {6, 4}, {7, 4}, {2, 5}, {3, 5}, {6, 5}, {7, 5}] do
        assert get_in(rows, [Access.at(y), Access.at(x)]) == :lake
      end
    end

    test "can't pass incorrect piece counts" do
      assert {:error, _} = Board.init_pieces(Board.new(), bad_piece_setup(), 2)
    end

    test "can't pass something other than 4 rows of 10" do
      placements =
        good_piece_setup()
        |> List.flatten()
        |> Enum.chunk_every(11)

      assert {:error, _} = Board.init_pieces(Board.new(), placements, 2)
    end
  end

  describe "translate_coord" do
    test "for player 1, no translation for coord" do
      for coord <- [{4, 2}, {5, 8}, {9, 0}] do
        assert ^coord = Board.translate_coord(coord, 1)
      end
    end

    test "for player 2, translation to player perspective for coord" do
      assert {2, 7} = Board.translate_coord({7, 2}, 2)
      assert {4, 8} = Board.translate_coord({5, 1}, 2)
      assert {9, 1} = Board.translate_coord({0, 8}, 2)
    end
  end

  describe "lookup_by_uuid" do
    test "for player 1, no translation" do
      {:ok, %Board{rows: rows} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 1)

      for {row, y} <- rows |> Enum.drop(6) |> Enum.zip(6..9) do
        for {piece, x} <- Enum.zip(row, 0..9) do
          assert {{^x, ^y}, ^piece} = Board.lookup_by_uuid(board, piece.uuid, 1)
        end
      end
    end

    test "for player 2, perspective for lookup is translated" do
      {:ok, %Board{rows: rows} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 2)

      for {row, y} <- rows |> Enum.take(4) |> Enum.zip(0..3) do
        for {piece, x} <- Enum.zip(row, 0..9) do
          translated_x = 9 - x
          translated_y = 9 - y

          assert {{^translated_x, ^translated_y}, ^piece} =
                   Board.lookup_by_uuid(board, piece.uuid, 2)
        end
      end
    end

    test "returns nil when no piece is present with that name" do
      {:ok, %Board{} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 1)
      assert nil == Board.lookup_by_uuid(board, "my-bogus-id", 1)
    end
  end

  describe "lookup_by_coord" do
    test "for player 1, no translation" do
      {:ok, %Board{rows: rows} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 1)

      for {row, y} <- rows |> Enum.drop(6) |> Enum.zip(6..9) do
        for {piece, x} <- Enum.zip(row, 0..9) do
          assert ^piece = Board.lookup_by_coord(board, {x, y}, 1)
        end
      end
    end

    test "for player 2, perspective for lookup is translated" do
      {:ok, %Board{rows: rows} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 2)

      for {row, y} <- rows |> Enum.take(4) |> Enum.zip(0..3) do
        for {piece, x} <- Enum.zip(row, 0..9) do
          assert ^piece = Board.lookup_by_coord(board, {9 - x, 9 - y}, 2)
        end
      end
    end

    test "when coordinate is out of bounds, doesn't error" do
      {:ok, %Board{} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 2)
      assert nil == Board.lookup_by_coord(board, {10, 0}, 1)
    end
  end

  describe "remove_pieces" do
    test "removes multiple pieces" do
      {:ok, %Board{} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 1)

      pieces_to_remove =
        board.rows
        |> Enum.at(Enum.random(6..9))
        |> Enum.take(2)

      new_board = Board.remove_pieces(board, pieces_to_remove)

      all_uuids =
        new_board.rows
        |> List.flatten()
        |> Enum.filter(&is_struct(&1))
        |> Enum.map(& &1.uuid)

      for piece <- pieces_to_remove do
        assert nil == Board.lookup_by_uuid(new_board, piece.uuid)
        assert nil == Enum.find(all_uuids, &(&1 == piece.uuid))
      end
    end
  end

  describe "remove_piece" do
    test "removes a piece, if it exists" do
      {:ok, %Board{} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 1)

      piece_to_remove =
        board.rows
        |> Enum.at(Enum.random(6..9))
        |> Enum.at(Enum.random(0..9))

      new_board = Board.remove_piece(board, piece_to_remove)

      all_uuids =
        new_board.rows
        |> List.flatten()
        |> Enum.filter(&is_struct(&1))
        |> Enum.map(& &1.uuid)

      assert nil == Board.lookup_by_uuid(new_board, piece_to_remove.uuid)
      assert nil == Enum.find(all_uuids, &(&1 == piece_to_remove.uuid))
    end

    test "doesn't fail if a bogus uuid is passed" do
      {:ok, %Board{} = board} = Board.init_pieces(Board.new(), good_piece_setup(), 1)
      new_board = Board.remove_piece(board, Piece.new(:marshall, 1))
      assert board == new_board
    end
  end

  describe "place_piece" do
    test "place a piece on the board" do
      board = Board.new()
      piece = Piece.new(:spy, 1)
      coord = {1, 8}
      {:ok, new_board} = Board.place_piece(board, piece, coord)

      assert piece == Board.lookup_by_coord(new_board, coord)
      assert {coord, piece} == Board.lookup_by_uuid(new_board, piece.uuid)
    end

    test "place a piece on the board for player 2 translates coordinate" do
      board = Board.new()
      piece = Piece.new(:flag, 2)
      coord = {3, 1}
      {:ok, new_board} = Board.place_piece(board, piece, coord, 2)

      assert piece == Board.lookup_by_coord(new_board, {6, 8})
      assert {{6, 8}, piece} == Board.lookup_by_uuid(new_board, piece.uuid)
    end

    test "place a piece on the board removes the piece from previous location" do
      board = Board.new()
      piece = Piece.new(:spy, 2)
      initial_coord = {2, 2}
      {:ok, initial_board} = Board.place_piece(board, piece, initial_coord, 2)

      new_coord = {2, 3}
      {:ok, new_board} = Board.place_piece(initial_board, piece, new_coord, 2)

      assert nil == Board.lookup_by_coord(new_board, {7, 7})
      assert piece == Board.lookup_by_coord(new_board, {7, 6})
      assert {{7, 6}, piece} == Board.lookup_by_uuid(new_board, piece.uuid)
    end

    test "won't place a piece where a lake is" do
      board = Board.new()
      piece = Piece.new(:flag, 1)
      initial_coord = {3, 5}

      assert {:error, "can't place a piece where a lake is"} =
               Board.place_piece(board, piece, initial_coord, 1)
    end

    test "won't place a piece out of bounds" do
      board = Board.new()
      piece = Piece.new(:scout, 1)
      initial_coord = {11, 6}

      assert {:error, "can't place a piece out of bounds"} =
               Board.place_piece(board, piece, initial_coord, 1)
    end
  end

  # mask board
  #   player 1
  #   player 2
  # move
  #   all 4 directions
  #   not into a lake
  #   not outside boundary
  #   attacks

  # describe "new" do

  #  test "fails when no name is passed" do
  #    assert_raise RuntimeError, ~r/^player must have a name!$/, fn ->
  #      Player.new(nil, 1)
  #    end
  #  end

  #  test "creates a new player will work for player 1 or 2" do
  #    name = ThisPlayer

  #    for n <- 1..2 do
  #      assert %Player{player: ^n, name: ^name} = Player.new(name, n)
  #    end
  #  end

  #  test "create a new player won't work for players outside that range" do
  #    assert_raise RuntimeError, ~r/^player valid range is 1-2!$/, fn ->
  #      Player.new(WhichPlayer, 3)
  #    end
  #  end
  # end
end
