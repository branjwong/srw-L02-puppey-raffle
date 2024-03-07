# Routine Tasks
report:
	docker run --rm \
       --volume "$(pwd):/data" \
       --user $(id -u):$(id -g) \
       pandoc/extra review/report.md -o review/report.pdf --template eisvogel --listings

# Local Dev Initialization

ln:
	ln -sf ../../review/src/PuppyRaffle.sol contracts/src/PuppyRaffle.sol
	ln -sf ../../review/test/PuppyRaffleTest.t.sol contracts/test/PuppyRaffleTest.t.sol

fixperm:
	sudo chmod -R a+rwX .
	sudo chmod -R g+rwX .
	sudo find . -type d -exec chmod g+s '{}' +

# Project Initialization

git_url := https://github.com/Cyfrin/4-puppy-raffle-audit.git

init:
	if [ ! -d "contracts" ]; then \
		git submodule add $(git_url) contracts; \
	fi
	git submodule update --init
