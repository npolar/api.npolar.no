{
    "id": "radiation-weather-api",
    "schema": "http://api.npolar.no/schema/api",
    "path": "/radiation-weather",
    "title": "Radiation/weather NP data API",
    "summary": "Norwegian Polar Institute's radiation and weather database",
    "storage": "Couch",
    "database": "radiation-weather",
    "model": "RadiationWeather",
    "search": {
        "engine": "Elasticsearch",
        "index": "radiation-weather",
        "type": "radiation-weather",
        "log": false,
        "params": {
            "facets": "interval,instrument-station,timestamp",
            "date-year": "released",
            "size-facet": 1000
        }
    },
    "verbs": [
        "DELETE",
        "GET",
        "HEAD",
        "POST",
        "PUT",
        "OPTIONS"
    ],
    "formats": {
        "json": "application/json"
    },
    "accepts": {
        "application/json": "https://api.npolar.no/schema/radiation-weather.json"
    },
    "category": [
        "CouchDB",
        "Lucene",
        "REST",
        "Search",
        "JSON",
        "JSON Schema",
        "HTTP"
    ],
    "lifecycle": "production",
    "run": "Npolar::Api::Json",
    "open": true,
    "middleware": [
        [
            "::Rack::Gouncer",
            {
                "url": "https://api.npolar.no/user/",
                "open": true,
                "system": "https://api.npolar.no/radiation-weather"
            }
        ]
    ]
}
