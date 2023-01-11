// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



// 1. Deploy Slave Contract on Binance Smart Chain
// 2. users deposit ETH on Ethereum Contract
// 4. Swap eth to usdt on pancakeswap ethereum
// 5. bridge usdt to binance using stargate
// 6. Swap usdt for bnb on pancakeswap binance
// 7. swap bnb for the same ratio as cake/bnb pool
// 8. For one year, Supply PancakeSwap with BNB and CAKE for 30% APY.
// ???????
// LAST. Users can withdraw their deposit and profit in USDC


contract BinanceBull is Ownable  {

    //can turn into an erc721 or erc20
    //user to shares
    mapping(address => uint) public userBalances;
    //total shares
    uint256 totalShares;

    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address pancakeRouter = 0xEfF92A263d31888d860bD50809A8D171709b7b1c;

    //make sure is ethereum address
    address stargateRouter = 0x8731d54E9D02c286767d56ac03e8037C07e01e98;


    //let users deposit
    function deposit() public payable {
        userBalances[msg.sender] += msg.value;
        totalShares += msg.value;
    }
/*    function withdraw() public returns(uint256) {
        totalShares -= userBalances[msg.sender];
        delete userBalances[msg.sender];

        
        uint256 withdrawAmt;
        return withdrawAmt;
    }
*/
    function getPathForETHtoUSDT() internal view returns (address[] memory) {
      
        IPancakeRouter pancake = IPancakeRouter(pancakeRouter);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = pancake.WETH();

        return path;
    }

    //airdrop some gas for the new contract
    function bridgeTokens() public payable {

        //Tether address
        //0xdAC17F958D2ee523a2206206994597C13D831ec7

        //Ethereum router address
        //0x8731d54E9D02c286767d56ac03e8037C07e01e98

        //Ethereum chainId: 101
        //Ethereum: 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675

        //Binance chainId: 102
        //Binance Endpoint: 0x3c2269811836af69497E5F486A85D7316753cf62

        //swap eth to tether *unused*
        //address pancakeETHUSDTPair = 0x17C1Ae82D99379240059940093762c5e4539aba5; 
  
        uint deadline = block.timestamp + 15;

        //swap tokens from ETH to USDT
        IPancakeRouter(pancakeRouter).swapExactETHForTokens{value:address(this).balance}(0,getPathForETHtoUSDT(),address(this),deadline);


        //approve all USDT to be bridged
        IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).approve(address(stargateRouter), IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7).balanceOf(msg.sender));

        IStargateRouter(stargateRouter).swap{value:msg.value} (
            1, //destination chain id
            101, // source pool id
            102, //destination pool id
            payable(msg.sender), //refund address for gas
            10000, // quantity to swap
            10000, //min quantity you would accept on destination chain
            IStargateRouter.lzTxObj(0, 0, "0x"), // param1 - gas limit increase, param2 - airdrop native gas, airdrop address
            abi.encodePacked(msg.sender), //address to send tokens to
            bytes("") //additional payload for layer zero
        );
    
    }

    function quoteLayerZeroFee() public {

        //LayerZero Transaction Object


        // encode payload data to send to destination contract, which it will handle with sgReceive()
        //  bytes memory payload = abi.encode(to);

        //get layer zero fee
        /* uint256 Fee = IStargateRouter(router).quoteLayerZeroFee(
        102, //destination chain Id
        1, // function type 1 for swap
        owner,
        payload,
        IStargateRouter.lzTxObj(500000, 0, "0x") //LayerZero Transaction Object
        );*/
    }

}

//contract to be deployed on Binance Smart Chain
contract BinanceBullSlave {
    //Ethereum router address
    //0x8731d54E9D02c286767d56ac03e8037C07e01e98

    //Binance router address
    //0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8

    //Ethereum chainId: 101
    //Ethereum: 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675

    //Binance chainId: 102
    //Binance Endpoint: 0x3c2269811836af69497E5F486A85D7316753cf62

    //Binance Bridge
    //0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97

    //USDT binance side
    //0x55d398326f99059fF775485246999027B3197955

    address stargateRouter = 0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8;
    address binanceBridge = 0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97;

    address pancakeRouter = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address USDTBNBPancakePair = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;

    address USDT = 0x55d398326f99059fF775485246999027B3197955;
    address CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address BNBCAKEPancakePair = 0x0eD7e52944161450477ee417DE9Cd3a859b14fD0;


    uint deadline = block.timestamp + 15; 
    

    // sgReceive() - the destination contract must implement this function to receive the tokens and payload
    function sgReceive(uint16 /*chainId*/, bytes memory /*_srcAddress*/, uint /*_nonce*/, address _token, uint amountLD, bytes memory _payload) external {
        require(msg.sender == address(stargateRouter), "only stargate router can call sgReceive!");
        (address _toAddr) = abi.decode(_payload, (address));
        // send transfer _token/amountLD to _toAddr
        IERC20(_token).transfer(_toAddr, amountLD);
        //depositPancake();

    }

    //utility for pancake swap
    function getPathForUSDTtoBNB() internal view returns (address[] memory) {
        //IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x93bcDc45f7e62f89a8e901DC4A0E2c6C427D9F25);
        IPancakeRouter pancake = IPancakeRouter(pancakeRouter);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = pancake.WETH();

        return path;
    }

    function getPathForBNBtoCAKE() internal view returns (address[] memory) {
        IPancakeRouter pancake = IPancakeRouter(pancakeRouter);
        address[] memory path = new address[](2);
        path[0] = pancake.WETH();
        path[1] = CAKE;

        return path;
    }


    function swapPancakeUSDTtoBNB() internal {
  
        //swap all BEP20(USDT) to BNB       
        IPancakeRouter(pancakeRouter).swapExactTokensForETH(IERC20(USDT).balanceOf(msg.sender),0,getPathForUSDTtoBNB(),address(this),deadline);

    }

    function swapPancakeBNBtoCAKE() internal {
        //get amount of cake needed for pool ratio
        //token0 = CAKE, token1 = BNB
        // retrieve current reserve amounts
        (uint112 CAKEamt,uint112 BNBamt, ) = IPancakePair(BNBCAKEPancakePair).getReserves();

        //calculate how much cake for BNB
        uint256 CAKEperBNB = IPancakeRouter(pancakeRouter).getAmountOut(1, BNBamt, CAKEamt );

        
        // Ex:
        // vault ratio =  1 bnb per 77 cake
        // amount of bnb in vault = 100
        // amount of bnb in vault after swap = 33
        // amount of cake in vault after swap = 77

        //calculate how much cake to buy
        //formula
        //bnb after swap = startingBNBamount - (startingBNBamount * (1/77) )
        //cake after swap  =  bnbafterswap  *  77


        uint bnbStartingAmt = address(this).balance;
        uint bnbAfterAmt = (bnbStartingAmt * CAKEperBNB);
        uint bnbToTrade = bnbStartingAmt - bnbAfterAmt;


    
        IPancakeRouter(pancakeRouter).swapExactETHForTokens{value: bnbToTrade}(0,getPathForBNBtoCAKE(),address(this),deadline);

    }



    function JUSTLPBROITSEZ() internal {

    }



}

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function deposit() external payable;
}

interface IPancakeRouter {

    function WETH() external pure returns (address);

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
    external
    pure
    returns (uint);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    returns (uint[] memory amounts);


    function addLiquidity(
    address tokenA,
    address tokenB,
    uint amountADesired,
    uint amountBDesired,
    uint amountAMin,
    uint amountBMin,
    address to,
    uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
}

interface IPancakePair {
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
}

interface IStargateRouter {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);

}

interface IStargateReceiver {
    function sgReceive(
        uint16 _srcChainId,              // the remote chainId sending the tokens
        bytes memory _srcAddress,        // the remote Bridge address
        uint256 _nonce,                  
        address _token,                  // the token contract on the local chain
        uint256 amountLD,                // the qty of local _token contract tokens  
        bytes memory payload
    ) external;

    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
}
