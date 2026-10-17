# db/seeds.rb

# Clear existing data, in dependency order. delete_all (not destroy_all) -
# destroy_all would instantiate and destroy every row individually, the same
# per-row overhead problem fixed everywhere else in this project.
Alert.delete_all
PriceCheck.delete_all
TrackingEvent.delete_all
Product.delete_all
Store.delete_all
Brand.delete_all

brands_products = {
  "The Prancing Pony" => [
    "Bree-Brewed Ale",
    "Hearthfire Stew",
    "Pony-Rider’s Travel Rations",
    "Barleybread Loaves",
    "Longbottom Leaf Sampler"
  ],
  "The Green Dragon Inn" => [
    "Green Dragon Ale",
    "Hobbiton Seed Cakes",
    "Shire-Style Cider",
    "Smial Breakfast Platter",
    "Toad in the Hole Mix"
  ],
  "Weasleys’ Wizard Wheezes" => [
    "Skiving Snackboxes",
    "Puking Pastilles",
    "Extendable Ears",
    "Decoy Detonators",
    "Peruvian Instant Darkness Powder"
  ],
  "Gringotts Wizarding Bank" => [
    "Vault Security Enchantments",
    "Gringotts Vault Keys",
    "Goblin-Forged Account Seals",
    "Currency Exchange Tokens",
    "Magical Appraisal Services"
  ],
  "Ollivanders Wand Shop" => [
    "Custom Hand-Matched Wands",
    "Wand Polishing Kits",
    "Core Stabilizing Charms",
    "Defensive Spark Training Wands",
    "Wand-Lore Compendium"
  ],
  "Honeydukes Sweetshop" => [
    "Chocolate Frogs",
    "Fizzing Whizzbees",
    "Acid Pops",
    "Pepper Imps",
    "Sugar-Quills",
    "Honey Toffee Bricks"
  ],
  "The Golden Company" => [
    "Mercenary Contracts",
    "Essosi War Steeds",
    "Company-Forged Swords",
    "Sellsword Armor Sets",
    "Dragonbone Trophies"
  ],
  "Iron Bank of Braavos" => [
    "High-Risk Maritime Loans",
    "Interest-Bound Iron Notes",
    "Braavosi Coin Assay Kits",
    "Debt Enforcement Services",
    "Iron Vault Depositories"
  ],
  "The Merchants of Novigrad" => [
    "Nilfgaardian Silk Trade Goods",
    "Temerian Spices & Herbs",
    "Merchant Guild Contracts",
    "Protected Trade Routes",
    "Dwarven Ledger Systems"
  ],
  "The Fishery" => [
    "Artificer’s Heat-Bricks",
    "Sympathetic Link Components",
    "Alchemical Resin Blocks",
    "Tempered Binding Wires",
    "University-Grade Crafting Tools"
  ],
  "Sea Folk Trading Clans" => [
    "Atha’an Miere Navigation Charts",
    "Sea Folk Glasswork",
    "Hand-tied Sailcloth Ropes",
    "Blue Coral Jewelry",
    "Storm-Firean Spice Trade Packs"
  ],
  "The Steel Ministry" => [
    "Ministry-Stamped Steel Ingots",
    "Inquisitor Forging Tools",
    "Allomantic Metal Purity Kits",
    "Hemalurgic Spikes",
    "Steel Alphabet Cipher Books"
  ],
  "House Venture Trading" => [
    "High-Grade Allomantic Metals",
    "Venture Luxury Textiles",
    "Nobleman’s Wine Reserve",
    "Luthadel Trade Permits",
    "House Venture Coin Tokens"
  ],
  "House Kholin Trading" => [
    "Shardplate Maintenance Oils",
    "Gemheart Transport Crates",
    "Stormlight Lanterns",
    "Kholin-Blade Practice Shards",
    "Shardbearer Scabbards"
  ],
  "The Guild of Artifabrians" => [
    "Soulcaster-Safe Containers",
    "Fabrial Heating Stones",
    "Spanreed Communications Sets",
    "Reverse-Lashing Toolkits",
    "Artifabrian Gemstone Housing Frames"
  ],
  "Loamhedge Abbey Brewery" => [
    "Abbey October Ale",
    "Mossflower Mead",
    "Sun-Baked Walnut Bread",
    "Berry-Spiced Cider",
    "Redwall Honeycakes"
  ],
  "The Mossflower Traders' Caravan" => [
    "Forest-Foraged Spices",
    "Woodland Cloth & Dyes",
    "Hand-Crafted Trinket Charms",
    "River-Moss Rope Coils",
    "Traveling Herb Pouches"
  ],
  "Spacing Guild" => [
    "Foldspace Navigation Contracts",
    "Guild-Approved Melange Supplements",
    "Heighliner Passage Tickets",
    "Navigator Isolation Tanks",
    "Guild Travel Permits"
  ],
  "Protogen Corporation" => [
    "Protomolecule Research Vials",
    "Advanced Biohazard Suits",
    "Black-Box R&D Devices",
    "Offworld Pathogen Filters",
    "Bio-Engineered Life Support Gel"
  ],
  "The Traders of the Foundation" => [
    "Foundation Tech Manuals",
    "Approved Atomic Devices",
    "Trade Route Contracts",
    "Miniaturized Energy Units",
    "Encyclopedic Data Cores"
  ],
  "Milliways Corporation" => [
    "Pan-Galactic Gargle Blasters",
    "Luxury Last-Meal Experiences",
    "Infinite-Table Reservations",
    "Recreational Singularity Pudding",
    "Reality-Warp Dessert Menu"
  ],
  "Omni Consumer Products" => [
    "Enforcement Droid Series (ED-209)",
    "OCP Crime Prevention Systems",
    "Cybernetic Replacement Limbs",
    "Urban Defense Architecture",
    "Robo-Integrated Monitoring Chips"
  ],
  "Capitol Science & Genetics Labs" => [
    "Capitol Gene-Splice Serums",
    "Capitol Cosmetic Enhancements",
    "Tracker Jacker Behavioral Kits",
    "Mockingjay Voice Synthesizers",
    "Peacekeeper Conditioning Drugs"
  ],
  "Wildfire Lab Complex" => [
    "Bio-Containment Nanogels",
    "Wildfire Decontamination Suits",
    "Pathogen Detection Modules",
    "Crisis Organism Culture Kits",
    "Emergency Sterilization Foam"
  ],
  "InGen Labs" => [
    "Dinosaur Genome Recovery Kits",
    "Bio-Containment Amber Extractors",
    "Paleo-DNA Sequencing Devices",
    "Rapid-Growth Nutrient Tanks",
    "Hybrid Species Genomes"
  ],
  "Umbrella Corporation" => [
    "T-Virus Sample Kits",
    "Bio-Organic Weapons",
    "Umbrella Medical First-Aid Sprays",
    "Umbrella Anti-Viral Inhibitors",
    "Research Hive Access Cards"
  ],
  "Nuka-Cola Corporation" => [
    "Nuka-Cola Quantum",
    "Nuka-Cola Victory",
    "Nuka-Cola Dark",
    "Nuka-Cherry",
    "Nuka-Cola Bottlecap Merch Packs"
  ],
  "Vault-Tec Corporation" => [
    "Vault Simulation Pip-Units",
    "Vault-Tec Emergency Rations",
    "Personal Pip-Boy Devices",
    "Cryo-Storage Modules",
    "Geiger Counter Home Kits"
  ],
  "Atlas Corporation" => [
    "Atlas Smart Rifles",
    "Prototype Energy Shields",
    "Legendary Atlas Armaments",
    "Corporate Loot Crates",
    "Tactical Mercenary Contracts"
  ],
  "Kojima Foods" => [
    "Tactical Bento Rations",
    "High-Protein Stealth Meals",
    "Camo-Flavored Energy Bars",
    "Field-Ready Meal Packs",
    "Cold-War Survival Kits"
  ],
  "Cerberus Network" => [
    "Covert Ops Armaments",
    "Augmented Soldier Implants",
    "Cerberus AI Platforms",
    "Quantum Shielding Vests",
    "Elite Operative Training Manuals"
  ],
  "Kanto Power Company" => [
    "Thunder Stone Energy Cells",
    "Power Plant Access Tokens",
    "Poké-Amp Charging Stations",
    "Magneton Field Stabilizers",
    "Volt Switch Circuit Kits"
  ],
  "Silph Co." => [
    "Ultra Balls and Master Balls",
    "Silph Scope",
    "Teleportation Prototype Modules",
    "Advanced TMs",
    "Trainer Communication Devices"
  ],
  "LexCorp" => [
    "Experimental Exo-Suits",
    "Kryptonite Research Kits",
    "LexCorp Drone Patrol Systems",
    "Mega-Construction Robotics",
    "Bio-Engineering Growth Tanks"
  ],
  "S.T.A.R. Labs" => [
    "Particle Accelerator Components",
    "Meta-Human Analysis Tools",
    "Temporal Rift Stabilizers",
    "Anti-Gravity Lens Arrays",
    "Tachyon Detector Cores"
  ],
  "Wayne Enterprises" => [
    "WayneTech Grapple Guns",
    "Reinforced Batsuits",
    "Batmobile Component Systems",
    "Corporate Security Drones",
    "Gotham Tactical Armor"
  ],
  "Stark Industries" => [
    "Arc Reactor Power Cells",
    "Iron Man Suit Components",
    "Repulsor Gauntlets",
    "Stark AI Toolkits",
    "Uni-Beam Energy Modules"
  ],
  "Oscorp" => [
    "Spider Enhancement Serums",
    "Oscorp Military Gliders",
    "Bio-Nanite Regeneration Gel",
    "Cross-Species Gene Splice Kits",
    "Oscorp Smart Bomb Prototypes"
  ],
  "Vought International" => [
    "Compound V",
    "Hero Marketing Kits",
    "Superhero Engagement Contracts",
    "Crisis PR Packages",
    "High-Risk Incident Insurance"
  ],
  "MomCorp" => [
    "Mom’s Friendly Robot Units",
    "Bending Robot Upgrades",
    "Delivery Drone Packages",
    "MomCorp Synthetic Oils",
    "Rebellion Suppression Systems"
  ],
  "Planet Express" => [
    "Intergalactic Delivery Contracts",
    "Emergency Teleporters",
    "Dark Matter Fuel Canisters",
    "Hyperspace Shipping Pods",
    "Captain’s Delivery Toolkit"
  ],
  "Strickland Propane" => [
    "Propane Tanks",
    "Propane Accessories",
    "Outdoor Grill Sets",
    "Backyard Burner Kits",
    "Certified Safety Valves"
  ],
  "Bilgewater Cartel" => [
    "Kaja’Cola",
    "Goblin Rocket Launchers",
    "High-Yield Mining Explosives",
    "Turbo-Charged Sprocket Kits",
    "Goblin Hot Rod Components"
  ],
  "Ironforge Steamworks" => [
    "Dwarven Boiler Engines",
    "Steam-Powered Mining Rigs",
    "Ironforge Forged Tools",
    "Precision Cogwheels",
    "Deep-Forge Pressure Valves"
  ],
  "Cenarion Circle Herbal Consortium" => [
    "Moonwell Healing Herbs",
    "Wildroot Growth Packs",
    "Druidic Salves",
    "Cenarion Seed Satchels",
    "Emerald Dream Infusion Oils"
  ]
}

store_addresses = [
  "1 Bagshot Row, Hobbiton, The Shire",
  "7 Green Dragon Lane, Bywater, The Shire",
  "3 Prancing Pony Way, Bree, Eriador",
  "221B Diagon Alley, London, Wizarding World",
  "9¾ Platform Plaza, King’s Cross, Wizarding World",
  "13 Honeydukes Corner, Hogsmeade Village",
  "1 Gringotts Vault Street, Diagon Alley, London",
  "14 Ollivander Row, Diagon Alley, London",
  "777 Golden Company Road, Volantis, Essos",
  "1 Iron Bank Terrace, Braavos, Essos",
  "4 Merchant’s Wharf, Novigrad, Redania",
  "12 Oxenfurt Bridge Road, Redania",
  "99 Kaer Morhen Pass, Kaedwen",
  "1 University Way, Imre, The Commonwealth",
  "8 Fishery Yard, Imre, The Commonwealth",
  "3 Waystone Inn Road, Newarre, The Commonwealth",
  "5 White Tower Square, Tar Valon, Westlands",
  "2 Sea Folk Docks, Tear Harbor",
  "15 Illuminators’ Alley, Cairhien City",
  "1 Kredik Shaw Heights, Luthadel, Final Empire",
  "10 Venture Keep Circle, Luthadel, Final Empire",
  "1 Kholin Plaza, Kholinar, Alethkar",
  "4 Shattered Plains Outpost, Alethkar",
  "16 Artifabrian Forge Lane, Urithiru",
  "1 Redwall Abbey Road, Mossflower Wood",
  "3 Loamhedge Brewery Trail, Mossflower",
  "7 Mossflower Caravan Route, Western Road",
  "101 Arrakeen Palace Way, Arrakis",
  "1 Guild Heighliner Dock, High Orbit, Arrakis Sector",
  "42 Milliways End-of-Universe Strip, Galactic Rim",
  "12 Foundation Trader’s Quay, Terminus City",
  "5 Trantor Spire Level, Imperial Sector",
  "209 OCP Plaza, Delta City, Michigan",
  "17 Wildfire Complex Tunnel, Nevada Desert",
  "1 InGen Research Park, Isla Nublar",
  "7 Umbrella Hive Access Road, Raccoon City",
  "13 Nuka-Cola Bottling Lane, Nuka-World",
  "101 Vault-Tec Control Boulevard, Los Angeles",
  "3 Atlas Armory Crescent, Promethea City",
  "5 Kojima Foods Test Kitchen, Shadow Moses Island",
  "12 Cerberus Black Site Road, Terminus System",
  "25 Normandy Dock, Citadel Ward",
  "1 Palaven Military Pier, Citadel Ward",
  "25 Kanto Power Plant Drive, Route 10, Kanto",
  "3 Silph Co. Tower, Saffron City, Kanto",
  "88 LexCorp Tower, Metropolis",
  "1007 Mountain Drive, Gotham City",
  "1 Wayne Enterprises Plaza, Gotham City",
  "108 Stark Tower, Midtown, New York",
  "13 Oscorp R&D Way, Midtown, New York",
  "1 Vought Tower, Manhattan, New York",
  "7 Planet Express Alley, New New York",
  "3 MomCorp Plaza, New New York",
  "135 Strickland Propane Road, Arlen, Texas",
  "1 Bilgewater Harbor Pier, Kezan",
  "7 Goblin Rocket Yard, Bilgewater Port",
  "3 Steamworks Foundry Street, Ironforge",
  "5 Deeprun Tram Approach, Ironforge Terminus",
  "9 Cenarion Enclave Path, Darnassus",
  "4 Moonglade Circle, Mount Hyjal",
  "2 Emerald Dreamway Gate, Val’sharah",
  "77 Shire Post Road, Michel Delving, The Shire",
  "21 Bree-Town Market Street, Bree, Eriador",
  "11 Hogsmeade High Street, Hogsmeade Village",
  "66 Knockturn Alley, London, Wizarding World",
  "2 Dragonstone Cliff Road, Blackwater Bay",
  "9 Sunspear Dune Way, Dorne",
  "8 Novigrad Temple Isle Lane, Redania",
  "17 Oxenfurt Academic Crescent, Redania",
  "3 Roke School Lane, Roke Island, Earthsea",
  "4 Gont Harbor Steps, Gont Island, Earthsea",
  "1 Caemlyn Palace Road, Andor",
  "7 Fal Dara Keep Close, Shienar",
  "2 Kredik Shaw Service Tunnel, Luthadel",
  "6 Kandra Alley, Fadrex City",
  "5 Kharbranth Harborfront, Kharbranth, Roshar",
  "2 Urithiru Highspire Level, Roshar",
  "9 Thaylen Gemstone Exchange Row, Thaylen City",
  "22 Loam Lane, Noonvale",
  "18 Salamandastron Beach Road, Western Shores",
  "3 Caladon Spaceport Gate, Arrakis Orbit",
  "6 Sietch Tabr Canyon Road, Arrakis",
  "1 Expanse Docking Ring, Tycho Station, The Belt",
  "9 Ceres Station Market Tier, The Belt",
  "7 Foundation Quay, Terminus Starport",
  "426 Galactic Way, Betelgeuse Sector",
  "5 Robocop Avenue, Old Detroit, Michigan",
  "13 Capitol Research Terrace, The Capitol",
  "2 Panem Train Platform, District 12",
  "7 Jurassic Dock, Isla Sorna",
  "4 Raccoon City General Street, Mid-West",
  "8 Nuka-World Main Concourse, Commonwealth",
  "11 Sanctuary Hills Circle, Commonwealth",
  "9 Tannis Research Spur, Pandora",
  "3 Crimson Raiders Garage, Sanctuary, Pandora",
  "12 Shadow Moses Supply Road, Fox Archipelago",
  "2 Illusive Man Lookout, Horizon System",
  "51 Indigo Plateau Loop, Kanto",
  "10 Pewter Gym Side Street, Kanto",
  "4 Daily Planet Plaza, Metropolis",
  "2 Gotham Gazette Row, Gotham City"
]

puts "Creating Brands and Products..."

brands_products.each do |brand_name, products|
  brand = Brand.create!(name: brand_name)

  products.each do |product_name|
    Product.create!(name: product_name, brand: brand)
  end
end

puts "Creating Stores..."

store_addresses.each do |address|
  Store.create!(address: address)
end

puts "Seed complete!"