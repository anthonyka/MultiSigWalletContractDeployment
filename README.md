# MultiSigWalletContractDeployment
This project creates a MultiSig wallet contract with contract deployment feature through Bytecode.
A simple example is made available in the [Test](Test) folder.

## Use
1. Deploy the MultiSig wallet on the blockchain
2. Get the Bytecode of a contract you want to deploy through the concensus-based mechanism provided by the wallet
3. Call the proposeSmartContract() function which takes the Bytecode as argument
4. Approve on contract deployment using signSmartContract()
     - When the minimum required number of votes is reached, the contract will be deployed emiting the contract address

## Testing
In order to test the contract without having to use web3.
1. Create a contract similar to [TestingInteraction](Test/TestingInteraction.sol)
     - Modify the functions in order to reflect the name of the functions in the destination contract you're interacting with and its parameters
2. Call the destination contract functions through the intermediary TestingInteraction functions you've created
