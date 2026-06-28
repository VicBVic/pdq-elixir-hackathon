defmodule School.Logic do
  # @desc_rules %{
  #   rule1: "Letters must weigh under 500g.",
  #   rule2: "International packages require a customs form.",
  #   rule3: "Fragile packages cannot use standard shipping.",
  #   rule4: "Parcels over 5000g must use priority shipping.",
  #   rule5: "Declared value over 100€ requires insurance.",
  #   rule6: "Fragile packages must have a fragile sticker.",
  #   rule7: "EU and international packages must use express or priority.",
  #   rule8: "Letters cannot have insurance.",
  #   rule9: "Standard shipping is only available for domestic packages under 2000g.",
  #   rule10: "Fragile international packages over 1000g must use priority."
  # }

  @type rule :: {atom(), %{atom() => any()}} | {:has_attr, [atom()]} | {:and | :or | :if, rule(), rule()}

  defp discrete_attributes_possible_values() do
    %{
      destination: [:domestic, :eu, :international],
      type: [:letter, :parcel, :fragile],
      shipping_class: [:standard, :express, :priority]
    }
  end

  defp continuous_attributes_max_values() do
    %{
      declared_value: 400,
      weight: 5000
    }
  end

  defp additional_attributes() do
    [
      :customs_form,
      :insurance,
      :fragile_sticker
    ]
  end

  defp primary_rule_tags() do
    [
      :equal,
      :not_equal,
      # :has_attr,
      :greater,
      :lesser
    ]
  end

  defp logical_rule_tags() do
    [
      :if,
      :or,
      :and
    ]
  end

  def generate_package() do
    %School.Package{
      type: Enum.random([:letter, :parcel, :fragile]),
      weight: Enum.random(1..5000),
      destination: Enum.random([:domestic, :eu, :international]),
      shipping_class: Enum.random([:standard, :express, :priority]),
      declared_value: Float.floor(:rand.uniform() * 400, 2),
      additional: []
    }
  end

  def validate_general(pattern, package, compare) do
    package_map = Map.from_struct(package)

    pattern
    |> Enum.filter(fn {key, _} -> Map.has_key?(package_map, key) end)
    |> Enum.count(fn {key, val} -> !compare.(Map.get(package_map, key), val) end) == 0
  end

  def validate_has_additional(list, package) do
    list
    |> Enum.count(fn val -> Enum.member?(package.additional, val) end) == length(list)
  end

  @spec validate(rule(), School.Package) :: boolean()
  def validate({:equal, pattern}, package) do
    validate_general(pattern, package, &Kernel.==/2)
  end

  def validate({:has_attr, list}, package) do
    validate_has_additional(list, package)
  end

  def validate({:not_equal, pattern}, package) do
    validate_general(pattern, package, &Kernel.!=/2)
  end

  def validate({:greater, pattern}, package) do
    validate_general(pattern, package, &Kernel.>/2)
  end

  def validate({:lesser, pattern}, package) do
    validate_general(pattern, package, &Kernel.</2)
  end

  def validate({:and, rule1, rule2}, package) do
    validate(rule1, package) && validate(rule2, package)
  end

  def validate({:or, rule1, rule2}, package) do
    validate(rule1, package) || validate(rule2, package)
  end

  def validate({:if, rule1, rule2}, package) do
    if validate(rule1, package) do
      validate(rule2, package)
    else
      true
    end
  end

  @spec rule_description(rule(), boolean()) :: String.t()
  def rule_description({:equal, rule}, absolute) do
    rule
    |> Enum.map(fn {key, val} -> "#{key} #{if absolute, do: "MUST be", else: "IS"} #{val}" end)
    |> Enum.join(" and ")
  end

  def rule_description({:lesser, rule}, absolute) do
    rule
    |> Enum.map(fn {key, val} ->
      "#{key} #{if absolute, do: "MUST be", else: "IS"} LESS than #{val}"
    end)
    |> Enum.join(" and ")
  end

  def rule_description({:greater, rule}, absolute) do
    rule
    |> Enum.map(fn {key, val} ->
      "#{key} #{if absolute, do: "MUST be", else: "IS"} GREATER than #{val}"
    end)
    |> Enum.join(" and ")
  end

  def rule_description({:not_equal, rule}, absolute) do
    rule
    |> Enum.map(fn {key, val} ->
      "#{key} #{if absolute, do: "MUST NOT be", else: "IS NOT"} #{val}"
    end)
    |> Enum.join(" and ")
  end

  def rule_description({:and, rule1, rule2}, absolute) do
    "#{rule_description(rule1, absolute)} AND #{rule_description(rule2, absolute)}"
  end

  def rule_description({:or, rule1, rule2}, absolute) do
    "#{rule_description(rule1, absolute)} OR #{rule_description(rule2, absolute)}"
  end

  def rule_description({:if, rule1, rule2}, _) do
    "IF #{rule_description(rule1, false)}, THEN #{rule_description(rule2, true)}"
  end

  def rule_description_set(rules) do
    rules
    |> Enum.map(fn rule -> rule_description(rule, true) end)
  end

  def validate_set(rules, package) do
    rules
    |> Enum.reduce(true, fn x, val -> val && validate(x, package) end)
  end

  @spec random_rule(atom()) :: rule()
  def random_rule(tag) when tag == :equal or tag == :not_equal do
    key = Enum.random(Map.keys(discrete_attributes_possible_values()))

    {tag,
     Map.put(
       %{},
       key,
       Enum.random(discrete_attributes_possible_values()[key])
     )}
  end

  def random_rule(tag) when tag == :lesser or tag == :greater do
    key = Enum.random(Map.keys(continuous_attributes_max_values()))

    {
      tag,
      Map.put(
        %{},
        key,
        :rand.uniform(continuous_attributes_max_values()[key])
      )
    }
  end

  def random_rule(:has_attr) do
    {
      :has_attr,
      Enum.random(additional_attributes())
    }
  end

  def random_rule(tag) when tag == :or or tag == :and or tag == :if do
    {
      tag,
      random_rule(Enum.random(primary_rule_tags())),
      random_rule(Enum.random(primary_rule_tags()))
    }
  end

  @spec random_rule() :: rule()
  def random_rule() do
    flip = :rand.uniform()
    if flip > 0.5, do: random_rule(Enum.random(logical_rule_tags())),
                    else: random_rule(Enum.random(primary_rule_tags()))
  end

  def random_rules(count \\ 3) do
    if count == 0, do: [], else: [random_rule() | random_rules(count-1)]
  end
end
