{
    "id": "weather-radiation-api",
    "schema": "http://api.npolar.no/schema/api",
    "path": "/weather-radiation",
    "title": "Weather/radiation NP data API",
    "summary": "Norwegian Polar Institute's radiation and weather database oiginal sampled data",
    "storage": "Couch",
    "database": "weather-radiation",
    "model": "WeatherRadiation",
    "search": {
        "engine": "Elasticsearch",
        "index": "weather-radiation",
        "type": "weather-radiation",
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
        "application/json": "https://api.npolar.no/schema/weather-radiation.json"
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
                "system": "https://api.npolar.no/weather-radiation"
            }
        ]
    ]
}
