class Animal
  def name(name)
    @name = name
    self
  end

  def species(species)
    @species = species
    self
  end

  def color(color)
    @color = color
    self
  end

  def natural_habitat(natural_habitat)
    @natural_habitat = natural_habitat
    self
  end

  def to_s
    "Name: #{@name}, Species: #{@species}, Color: #{@color}, Natural Habitat: #{@natural_habitat}"
  end
end
