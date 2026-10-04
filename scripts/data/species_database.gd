class_name SpeciesDatabase
extends Resource
## Список всех видов (resources/species_db.tres).

@export var species: Array[SpeciesData] = []


func by_biome(biome: int) -> Array[SpeciesData]:
	var result: Array[SpeciesData] = []
	for s: SpeciesData in species:
		if s.biome == biome:
			result.append(s)
	return result
