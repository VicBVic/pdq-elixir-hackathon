defmodule School.Package do

  @type ptype ::  :letter | :parcel | :fragile
  @type dest :: :domestic | :eu | :international
  @type shipping_class :: :standard | :express | :priority
  @type t :: %School.Package {
    type:                ptype(),
    weight:              pos_integer(),
    destination:         dest(),
    shipping_class:     shipping_class(),
    declared_value:      float(),
    additional: list(atom())
  }

  defstruct type: :letter,
  weight: 0,
  destination: :domestic,
  shipping_class: :standard,
  declared_value: 0,
  additional: []
end
