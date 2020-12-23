defmodule SurfaceFormatter.Test do
  use Surface.Component

  def render(assigns) do
    ~H"""
    <div class=        "LOL">
                {{ 1 +        1 }}
      <span>lol
    </span>
        </div>
    """
  end

  defp func(assigns) do
    ~H"""
    <section>           separate
    h
    <div>sigil</div>
    </section>
    """
  end
end
