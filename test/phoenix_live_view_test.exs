defmodule Phoenix.LiveViewUnitTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveView

  alias Phoenix.LiveView.{Utils, Socket}
  alias Phoenix.LiveViewTest.Endpoint

  @socket Utils.configure_socket(
            %Socket{endpoint: Endpoint, router: Phoenix.LiveViewTest.Router},
            %{connect_params: %{}},
            nil
          )

  describe "get_connect_params" do
    test "raises when not in mounting state and connected" do
      socket = Utils.post_mount_prune(%{@socket | connected?: true})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "raises when not in mounting state and disconnected" do
      socket = Utils.post_mount_prune(%{@socket | connected?: false})

      assert_raise RuntimeError, ~r/attempted to read connect_params/, fn ->
        get_connect_params(socket)
      end
    end

    test "returns nil when disconnected" do
      socket = %{@socket | connected?: false}
      assert get_connect_params(socket) == nil
    end

    test "returns params connected and mounting" do
      socket = %{@socket | connected?: true}
      assert get_connect_params(socket) == %{}
    end
  end

  describe "assign_new" do
    test "uses socket assigns if no parent assigns are present" do
      socket =
        @socket
        |> assign(existing: "existing")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing",
               notexisting: "new-notexisting",
               live_view_module: nil,
               live_view_action: nil
             }
    end

    test "uses parent assigns when present and falls back to socket assigns" do
      socket =
        put_in(@socket.private[:assigned_new], {%{existing: "existing-parent"}, []})
        |> assign(existing2: "existing2")
        |> assign_new(:existing, fn -> "new-existing" end)
        |> assign_new(:existing2, fn -> "new-existing2" end)
        |> assign_new(:notexisting, fn -> "new-notexisting" end)

      assert socket.assigns == %{
               existing: "existing-parent",
               existing2: "existing2",
               notexisting: "new-notexisting",
               live_view_module: nil,
               live_view_action: nil
             }
    end
  end

  describe "redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in redirect/2 expects a path", fn ->
        redirect(@socket, to: "//foo.com")
      end

      assert redirect(@socket, to: "/foo").redirected == {:redirect, %{to: "/foo"}}
    end

    test "allows external paths" do
      assert redirect(@socket, external: "http://foo.com/bar").redirected ==
               {:redirect, %{to: "http://foo.com/bar"}}
    end
  end

  describe "push_redirect/2" do
    test "requires local path on to" do
      assert_raise ArgumentError, ~r"the :to option in push_redirect/2 expects a path", fn ->
        push_redirect(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_redirect/2 expects a path", fn ->
        push_redirect(@socket, to: "//foo.com")
      end

      assert push_redirect(@socket, to: "/counter/123").redirected ==
               {:live, :redirect, %{kind: :push, to: "/counter/123"}}
    end
  end

  describe "push_patch/2" do
    test "requires local path on to pointing to the same LiveView" do
      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "http://foo.com")
      end

      assert_raise ArgumentError, ~r"the :to option in push_patch/2 expects a path", fn ->
        push_patch(@socket, to: "//foo.com")
      end

      assert_raise ArgumentError,
                   ~r"cannot push_patch/2 to \"/counter/123\" because the given path does not point to the current view",
                   fn ->
                     push_patch(@socket, to: "/counter/123")
                   end

      socket = %{@socket | view: Phoenix.LiveViewTest.ParamCounterLive}

      assert push_patch(socket, to: "/counter/123").redirected ==
               {:live, {%{"id" => "123"}, nil}, %{kind: :push, to: "/counter/123"}}
    end
  end
end
