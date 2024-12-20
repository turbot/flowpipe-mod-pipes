mod "pipes" {
  title         = "Turbot Pipes"
  description   = "Run pipelines to supercharge your Pipes workflows using Flowpipe."
  color         = "#FABF1B"
  documentation = file("./README.md")
  icon          = "/images/mods/turbot/pipes.svg"
  categories    = ["data management", "library"]

  opengraph {
    title       = "Turbot Pipes Mod for Flowpipe"
    description = "Run pipelines to supercharge your Pipes workflows using Flowpipe."
    image       = "/images/mods/turbot/pipes-social-graphic.png"
  }

  require {
    flowpipe {
      min_version = "1.0.0"
    }
  }
}
