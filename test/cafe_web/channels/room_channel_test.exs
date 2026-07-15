defmodule CafeWeb.RoomChannelTest do
  use CafeWeb.ChannelCase

  setup do
    {:ok, _, socket} =
      CafeWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(CafeWeb.RoomChannel, "room:lobby", %{"name" => "test-user"})

    %{socket: socket}
  end

  test "joining sends the current presence state" do
    assert_push "presence_state", %{"test-user" => _presence}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end
