module CompactIndex
  Gem = Struct.new(:name, :versions) do
    def <=>(other)
      name <=> other.name
    end
  end
end
