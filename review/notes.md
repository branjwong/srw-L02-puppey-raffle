# About Project

This project is a raffle. Winners enter, one ticket per address, and pay an entrance fee in Ethereum. If they win, they receive 80% of the pot and are minted a cute dog NFT. They may refund and get 100% of their funds back before the winner is declared.

Main Entrypoint: `enterRaffle` (public, payable, modifies state).

Other entrypoints:

- `refund` (external, modifies state)
- `withdrawFees` (external, modifies state)

# Hypotheses

The contract can be broken so that:

1. use duplicate addressess // @audit not sure what this means
2. deplete the contract of funds via `refund`
3. non-owner of protocol can set feeAddress
4. refunding after winner declared

# Notes

- this is a one-time raffle. once it ends, it can't be run again. this is b/c the start-time isn't reset. you can re-deploy this contract to run a new raffle

# Informational

- custom reverts
- i_, s_, for immutable and storage variables

# Gas

- checking for duplicates, can be O(n) loop instead of O(n^2)
