# Project description

The project description is given in `contracts/README.md`.

> This project is to enter a raffle to win a cute dog NFT. The protocol should do the following:
> 1. Call the `enterRaffle` function with the following parameters:
>    1. `address[] participants`: A list of addresses that enter. You can use this to enter yourself multiple times, or yourself and a group of your friends.
> 2. Duplicate addresses are not allowed
> 3. Users are allowed to get a refund of their ticket & `value` if they call the `refund` function
> 4. Every X seconds, the raffle will be able to draw a winner and be minted a random puppy
> 5. The owner of the protocol will set a feeAddress to take a cut of the `value`, and the rest of the funds will be sent to the winner of the puppy.

# Hypotheses

The contract can be broken so that:

1. use duplicate addressess // @audit not sure what this means
2. deplete the contract of funds via `refund`
3. non-owner of protocol can set feeAddress
4.

# Notes

- this is a one-time raffle. once it ends, it can't be run again. this is b/c the start-time isn't reset. you can re-deploy this contract to run a new raffle
