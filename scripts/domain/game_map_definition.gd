class_name GameMapDefinition
extends RefCounted

var cities: Array[MapCityDefinition]
var connections: Array[MapConnection]


func _init(
	city_definitions: Array[MapCityDefinition],
	city_connections: Array[MapConnection]
) -> void:
	cities = city_definitions
	connections = city_connections


func find_city(city_id: String) -> MapCityDefinition:
	for city: MapCityDefinition in cities:
		if city.id == city_id:
			return city
	return null


static func create_western_front() -> GameMapDefinition:
	var cities: Array[MapCityDefinition] = [
		MapCityDefinition.new("paris", "Paris", Vector2(0.08, 0.76), true),
		MapCityDefinition.new("mezieres", "Mezieres", Vector2(0.78, 0.20)),
		MapCityDefinition.new("verdun", "Verdun", Vector2(0.63, 0.60)),
		MapCityDefinition.new("meaux", "Meaux", Vector2(0.20, 0.68)),
		MapCityDefinition.new("albert", "Albert", Vector2(0.20, 0.40)),
		MapCityDefinition.new("nancy", "Nancy", Vector2(0.78, 0.68)),
		MapCityDefinition.new("amiens", "Amiens", Vector2(0.20, 0.28)),
		MapCityDefinition.new("rheims", "Rheims", Vector2(0.48, 0.48)),
		MapCityDefinition.new("la_bassee", "La Bassee", Vector2(0.08, 0.28)),
		MapCityDefinition.new("lille", "Lille", Vector2(0.20, 0.16)),
		MapCityDefinition.new("maubeuge", "Maubeuge", Vector2(0.48, 0.28)),
		MapCityDefinition.new("soissons", "Soissons", Vector2(0.34, 0.60)),
		MapCityDefinition.new("valenciennes", "Valenciennes", Vector2(0.34, 0.28)),
		MapCityDefinition.new("cambrai", "Cambrai", Vector2(0.34, 0.40)),
		MapCityDefinition.new("saint_quentin", "Saint-Quentin", Vector2(0.34, 0.48)),
		MapCityDefinition.new("laon", "Laon", Vector2(0.48, 0.60)),
		MapCityDefinition.new("hirson", "Hirson", Vector2(0.63, 0.28)),
		MapCityDefinition.new("mons", "Mons", Vector2(0.48, 0.16)),
		MapCityDefinition.new("ghent", "Ghent", Vector2(0.20, 0.04)),
		MapCityDefinition.new("tournai", "Tournai", Vector2(0.34, 0.16)),
		MapCityDefinition.new("ypres", "Ypres", Vector2(0.08, 0.16)),
		MapCityDefinition.new("liege", "Liege", Vector2(0.78, 0.28)),
		MapCityDefinition.new("brussels", "Brussels", Vector2(0.63, 0.04)),
		MapCityDefinition.new("charleroi", "Charleroi", Vector2(0.63, 0.16)),
		MapCityDefinition.new("namur", "Namur", Vector2(0.78, 0.40)),
		MapCityDefinition.new("antwerp", "Antwerp", Vector2(0.48, 0.04)),
		MapCityDefinition.new("luxembourg", "Luxembourg", Vector2(0.92, 0.48)),
		MapCityDefinition.new("metz", "Metz", Vector2(0.78, 0.56)),
		MapCityDefinition.new("koblenz", "Koblenz", Vector2(0.92, 0.16), true),
		MapCityDefinition.new("strasbourg", "Strasbourg", Vector2(0.92, 0.76)),
		MapCityDefinition.new("aachen", "Aachen", Vector2(0.92, 0.04)),
		MapCityDefinition.new("saarbrucken", "Saarbrucken", Vector2(0.92, 0.64)),
	]
	var connections: Array[MapConnection] = [
		MapConnection.new("paris", "meaux"),
		MapConnection.new("paris", "soissons"),
		MapConnection.new("paris", "amiens"),
		MapConnection.new("meaux", "soissons"),
		MapConnection.new("meaux", "verdun"),
		MapConnection.new("amiens", "albert"),
		MapConnection.new("amiens", "cambrai"),
		MapConnection.new("albert", "cambrai"),
		MapConnection.new("albert", "saint_quentin"),
		MapConnection.new("ypres", "lille"),
		MapConnection.new("ypres", "la_bassee"),
		MapConnection.new("lille", "la_bassee"),
		MapConnection.new("lille", "tournai"),
		MapConnection.new("la_bassee", "valenciennes"),
		MapConnection.new("tournai", "valenciennes"),
		MapConnection.new("tournai", "mons"),
		MapConnection.new("valenciennes", "cambrai"),
		MapConnection.new("valenciennes", "maubeuge"),
		MapConnection.new("cambrai", "saint_quentin"),
		MapConnection.new("saint_quentin", "laon"),
		MapConnection.new("saint_quentin", "maubeuge"),
		MapConnection.new("soissons", "laon"),
		MapConnection.new("soissons", "rheims"),
		MapConnection.new("laon", "rheims"),
		MapConnection.new("laon", "hirson"),
		MapConnection.new("rheims", "verdun"),
		MapConnection.new("rheims", "mezieres"),
		MapConnection.new("maubeuge", "mons"),
		MapConnection.new("maubeuge", "hirson"),
		MapConnection.new("mons", "brussels"),
		MapConnection.new("mons", "charleroi"),
		MapConnection.new("ghent", "antwerp"),
		MapConnection.new("ghent", "lille"),
		MapConnection.new("antwerp", "brussels"),
		MapConnection.new("brussels", "charleroi"),
		MapConnection.new("brussels", "liege"),
		MapConnection.new("liege", "aachen"),
		MapConnection.new("liege", "namur"),
		MapConnection.new("charleroi", "namur"),
		MapConnection.new("namur", "luxembourg"),
		MapConnection.new("hirson", "mezieres"),
		MapConnection.new("mezieres", "luxembourg"),
		MapConnection.new("luxembourg", "metz"),
		MapConnection.new("metz", "verdun"),
		MapConnection.new("metz", "nancy"),
		MapConnection.new("metz", "saarbrucken"),
		MapConnection.new("nancy", "strasbourg"),
		MapConnection.new("nancy", "saarbrucken"),
		MapConnection.new("saarbrucken", "strasbourg"),
		MapConnection.new("saarbrucken", "koblenz"),
		MapConnection.new("aachen", "koblenz"),
		MapConnection.new("koblenz", "luxembourg"),
	]
	return GameMapDefinition.new(cities, connections)
