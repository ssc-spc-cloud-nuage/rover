
default: github

github: 
	@bash "$(CURDIR)/scripts/build_image_ssc.sh" "github"

local:
	@bash "$(CURDIR)/scripts/build_image_ssc.sh" "local"

dev:
	@bash "$(CURDIR)/scripts/build_image_ssc.sh" "dev"
