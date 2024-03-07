project := addr

ln: 
	rm contracts/src/PuppyRaffle.sol && \
	ln -s ../../review/src/PuppyRaffle.sol contracts/src/PuppyRaffle.sol && \
	rm contracts/test/PuppyRaffleTest.t.sol && \
	ln -s ../../review/test/PuppyRaffleTest.t.sol contracts/test/PuppyRaffleTest.t.sol

clone:
	git submodule add $(project) contracts

fixperm:
	sudo chmod -R a+rwX . && \
	sudo chmod -R g+rwX . && \
	sudo find . -type d -exec chmod g+s '{}' +

report:
	docker run --rm \
       --volume "$(pwd):/data" \
       --user $(id -u):$(id -g) \
       pandoc/extra review/report.md -o review/report.pdf --template eisvogel --listings