#!/bin/bash
# Run this script to install dependencies when network is available

set -e

echo "Installing Uniswap v4-core..."
forge install uniswap/v4-core

echo "Installing Uniswap v4-periphery..."
forge install uniswap/v4-periphery

echo "Installing OpenZeppelin contracts..."
forge install openzeppelin/openzeppelin-contracts

echo "Installing forge-std..."
forge install foundry-rs/forge-std

echo "All dependencies installed successfully!"
echo "Run 'forge build' to compile the project."
