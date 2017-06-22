defmodule Slackbot.OrderList do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Slackbot.OrderEntry
  alias Slackbot.OrderList
  alias Slackbot.Repo

  require Logger

  schema "order_lists" do
    field :open, :boolean
    many_to_many :order_entries,
                 Slackbot.OrderEntry,
                 join_through: "order_entries_order_lists",
                 on_delete: :delete_all
    timestamps
  end

  def changeset(orderlist, params \\ %{}) do
    orderlist
    |> Repo.preload(:order_entries)
    |> cast(params, [:open])
    |> cast_assoc(:order_entries)
  end

  #################
  # Api Functions #
  #################

  def close_orderlist() do
    orderlist = latest_orderlist()
    # Close the order list
    orderlist_cs = changeset(orderlist, %{open: false})
    orderlist = Repo.update! orderlist_cs
    # Immediatly start a new one
    start_new_order()
  end

  def current_orders() do
    create_orderlist_if_none()
    orderlist = create_orderlist_if_none()
    orderlist.order_entries
  end

  def store_order(order_entry) do
    create_orderlist_if_none()
    |> add_order_to_current(order_entry)
  end

  def current_order_by(username) do
    orderlist = latest_orderlist()
    case orderlist do
      nil -> nil
      ol  -> if orderlist.open == true do
                orders = orderlist.order_entries
                |> Enum.filter(fn(e) -> e.user == username end)
                case orders do
                  [] -> nil
                  xs -> hd xs
                end
              else
                nil
              end
    end
  end

  def delete_current_order_by(username) do
    order = current_order_by(username)
    IO.inspect order
    case order do
      nil -> {:ok, :not_found}
      _   -> Repo.delete! order
             {:ok, :deleted}
    end
  end

  #####################
  # Private Functions #
  #####################

  defp create_orderlist_if_none() do
    most_recent = Repo.one(from(ol in OrderList, order_by: [desc: ol.inserted_at], limit: 1)) |> Repo.preload(:order_entries)
    case most_recent do
      nil -> start_new_order()
      x   -> if x.open do
               x
             else
               start_new_order()
             end
    end
  end

  defp add_order_to_current(orderlist, orderentry) do
    orders = orderlist.order_entries
    orderlist_cs = changeset(orderlist)
    orderlist_cs = Ecto.Changeset.put_assoc(orderlist_cs, :order_entries, [orderentry | orders])
    orderlist = Repo.update! orderlist_cs
    orderlist
  end

  defp start_new_order() do
    orderlist = %OrderList{open: true}
    orderlist = Repo.insert! orderlist |> Repo.preload(:order_entries)
    orderlist
  end

  def latest_orderlist() do
    create_orderlist_if_none()
    most_recent = Repo.one(from(ol in OrderList, order_by: [desc: ol.inserted_at], limit: 1)) |> Repo.preload(:order_entries)
    most_recent
  end

end
