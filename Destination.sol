// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
	mapping( address => address) public underlying_tokens;
	mapping( address => address) public wrapped_tokens;
	address[] public tokens;

	event Creation( address indexed underlying_token, address indexed wrapped_token );
	event Wrap( address indexed underlying_token, address indexed wrapped_token, address indexed to, uint256 amount );
	event Unwrap( address indexed underlying_token, address indexed wrapped_token, address frm, address indexed to, uint256 amount );

    constructor( address admin ) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

	function wrap(address _underlying_token, address _recipient, uint256 _amount ) public onlyRole(WARDEN_ROLE) {
		// 1. Look up the wrapped token address for this underlying token
        address wrapped_token_address = wrapped_tokens[_underlying_token];

        // 2. Verify that the token has been registered (wrapped token exists)
        require(wrapped_token_address != address(0), "Destination: Token not registered");

        // 3. Mint the wrapped tokens to the recipient
        //    The Destination contract has MINTER_ROLE because it was set as admin in createToken
        BridgeToken(wrapped_token_address).mint(_recipient, _amount);

        // 4. Emit the Wrap event
        emit Wrap(_underlying_token, wrapped_token_address, _recipient, _amount);
	}

	function unwrap(address _wrapped_token, address _recipient, uint256 _amount ) public {
		// 1. Look up the underlying token address to verify this is a valid wrapped token
        address underlying_token_address = underlying_tokens[_wrapped_token];
        require(underlying_token_address != address(0), "Destination: Not a wrapped token");

        // 2. Burn the wrapped tokens from the caller (msg.sender)
        //    Use burnFrom to burn from msg.sender's balance
        //    BridgeToken's burnFrom allows MINTER_ROLE to burn without allowance,
        //    but since we're the Destination contract with MINTER_ROLE, this works
        BridgeToken(_wrapped_token).burnFrom(msg.sender, _amount);

        // 3. Emit the Unwrap event
        //    'frm' = msg.sender (who is burning tokens on destination chain)
        //    'to' = _recipient (who will receive underlying tokens on source chain)
        emit Unwrap(underlying_token_address, _wrapped_token, msg.sender, _recipient, _amount);
	}

	function createToken(address _underlying_token, string memory name, string memory symbol ) public onlyRole(CREATOR_ROLE) returns(address) {
		// 1. Deploy a new BridgeToken contract
        //    Pass the underlying token address, name, symbol, and this contract as admin
        //    Setting address(this) as admin gives this Destination contract the MINTER_ROLE
        BridgeToken new_wrapped_token = new BridgeToken(_underlying_token, name, symbol, address(this));
        address wrapped_address = address(new_wrapped_token);

        // 2. Update the mappings to track the relationship between tokens
        //    wrapped_tokens: underlying address -> wrapped address
        //    underlying_tokens: wrapped address -> underlying address
        wrapped_tokens[_underlying_token] = wrapped_address;
        underlying_tokens[wrapped_address] = _underlying_token;

        // 3. Emit the Creation event
        emit Creation(_underlying_token, wrapped_address);

        // 4. Return the address of the newly created wrapped token
        return wrapped_address;
	}

}