#!/bin/bash
#
# User data
# This data is necessary for the configuration and functioning of Git and SSH
# If you don't put the data in now, you'll need to configure .gitconfig and SSH later

DRY_RUN="${DRY_RUN:-false}"

# User variables (never prompt in dry-run mode: use placeholders instead)
if [ -z "$GIT_NAME" ]; then
	if [ "$DRY_RUN" = true ]; then
		GIT_NAME="(dry-run)"
	else
		read -p " -> Enter your name for Git: " GIT_NAME
	fi
fi
if [ -z "$GIT_EMAIL" ]; then
	if [ "$DRY_RUN" = true ]; then
		GIT_EMAIL="(dry-run)"
	else
		read -p " -> Enter your email for Git: " GIT_EMAIL
	fi
fi

# Export variables for next scripts
export GIT_NAME
export GIT_EMAIL

# Guidance
# - GIT_NAME: name and surname to use in Git settings.
# - GIT_EMAIL: email to use in Git settings.

# Example
# - GIT_NAME: "John Doe"
# - GIT_EMAIL: "johndoe@example"
