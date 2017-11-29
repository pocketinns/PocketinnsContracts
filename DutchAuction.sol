pragma solidity 0.4.18;

/// @title Abstract token contract - Functions to be implemented by token contracts.
contract Token {

    uint public totalSupply;
    function totalSupply() public constant returns(uint total_Supply);
    function balanceOf(address who) public constant returns(uint256);
    function allowance(address owner, address spender) public constant returns(uint);
    function transferFrom(address from, address to, uint value) public returns(bool ok);
    function approve(address spender, uint value) public returns(bool ok);
    function transfer(address to, uint value)public returns(bool ok);
    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

/// @title Standard token contract - Standard token interface implementation.
contract PocketinnsToken is Token {

    /*
     *  Token meta data
     */
    // string constant public name = "Pocketinns Token";
    // string constant public symbol = "Pinns";
    // uint8 constant public decimals = 18;
    address public owner;
    address public dutchAuctionAddress;
    
     modifier onlyForDutchAuctionContract() {
        if (msg.sender != dutchAuctionAddress)
            // Only owner is allowed to proceed
            revert();
        _;
    }
    
    
    /*
     *  Data structures
     */
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalSupply;

    /*
     *  Public functions
     */
 
    
    function PocketinnsToken(address dutchAuction) public
    {
        owner = msg.sender;
        totalSupply = 150000000 * 10**18;
        balances[dutchAuction] = 30000000 * 10**18;
        balances[owner] = 120000000 * 10**18;
        dutchAuctionAddress = dutchAuction;  // we have stored the dutch auction contract address for burning tokens present after ITO
    }
    
    function burnLeftItoTokens(uint _burnValue)
    public
    onlyForDutchAuctionContract
    {
        totalSupply -=_burnValue;
         balances[dutchAuctionAddress] -= _burnValue;
    }
     
    /// @dev Transfers sender's tokens to a given address. Returns success.
    /// @param _to Address of token receiver.
    /// @param _value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transfer(address _to, uint256 _value)
        public
        returns (bool)
    {
        if (balances[msg.sender] < _value) {
            // Balance too low
            revert();
        }
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        Transfer(msg.sender, _to, _value);
        return true;
    }

    /// @dev Allows allowed third party to transfer tokens from one address to another. Returns success.
    /// @param _from Address from where tokens are withdrawn.
    /// @param _to Address to where tokens are sent.
    /// @param _value Number of tokens to transfer.
    /// @return Returns success of function call.
    function transferFrom(address _from, address _to, uint256 _value)
        public
        returns (bool)
    {
        if (balances[_from] < _value || allowed[_from][msg.sender] < _value) {
            // Balance or allowance too low
            revert();
        }
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        Transfer(_from, _to, _value);
        return true;
    }

    /// @dev Sets approved amount of tokens for spender. Returns success.
    /// @param _spender Address of allowed account.
    /// @param _value Number of approved tokens.
    /// @return Returns success of function call.
    function approve(address _spender, uint256 _value)
        public
        returns (bool)
    {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /*
     * Read functions
     */
    /// @dev Returns number of allowed tokens for given address.
    /// @param _owner Address of token owner.
    /// @param _spender Address of token spender.
    /// @return Returns remaining allowance for spender.
    function allowance(address _owner, address _spender)
        constant
        public
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    /// @dev Returns number of tokens owned by given address.
    /// @param _owner Address of token owner.
    /// @return Returns balance of owner.
    function balanceOf(address _owner)
        constant
        public
        returns (uint256)
    {
        return balances[_owner];
    }
    
    function totalSupply() public constant returns(uint total_Supply)
    {
        return totalSupply;
    }
}


contract pinnsDutchAuction
    {
    
    
    uint constant public MAX_TOKENS = 30000000 * 10**18; // 30M pinns Token
    uint constant public minimumInvestment = 1 * 10**18; // 1 ether is minimum minimumInvestment        
    uint constant public goodwillTokensAmount = 5000000 * 10**18; // 5M pinns Token
    
    Stages public stage;
    
     /*
     *  Enums
     */
    enum Stages {
        AuctionDeployed,
        AuctionSetUp,
        AuctionStarted,
        AuctionEnded,
        goodwillDistributionStarted
    }
     
     /*
     *  Storage
     */
    PocketinnsToken public pinnsToken;
    address public owner;
    // uint public ceiling;
    uint public priceFactor;
  

    /*
     *  Store to maintain the status and details of the investors,
     *  who invest in first four days for distributing goodwill bonus tokens
     */
    
    uint256 public bonusRecipientCount;
    mapping (address => bool) public goodwillBonusStatus; 
    mapping (address => uint) public bonusTokens; // the bonus tokens to be received by investors for first four days
    
     /*
     *  Variables to store the total amount recieved for first four days and total recieved
     */
    uint256 public fourDaysRecieved;
    uint256 public totalReceived;

    uint256 public startItoTimestamp; // to store the starting time of the ITO
    uint256 public pricePerToken;
    uint256 public startPricePerToken;
    uint256 public currentPerTokenPrice;   
    uint256 public finalPrice;
    uint256 public totalTokensSold;
    
    mapping (address => uint256) public noBonusDays;
    mapping (address => uint256) public itoBids;
    event ito(address investor, uint256 amount, string day);
    
     /*
     *  Modifiers
     */
     
    modifier atStage(Stages _stage) {
        if (stage != _stage)
            // Contract not in expected state
            revert();
        _;
    }

    modifier isOwner() {
        if (msg.sender != owner)
            // Only owner is allowed to proceed
            revert();
        _;
    }

    modifier isValidPayload() {
        if (msg.data.length != 4 && msg.data.length != 36)
            revert();
        _;
    }

    function pinnsDutchAuction(uint256 EtherPriceFactor)
        public
    {
        require(EtherPriceFactor != 0);
        owner = msg.sender;
        stage = Stages.AuctionDeployed;
        priceFactor = EtherPriceFactor;
    }
     
    
    // /// @dev Setup function sets external contracts' addresses.
    // /// @param pinnsToken pinnns token address.
    function startICO(address _pinnsToken) public
        isOwner
        atStage(Stages.AuctionDeployed)
        {
        require(_pinnsToken !=0);
        pinnsToken = PocketinnsToken(_pinnsToken);
        // Validate token balance
        require (pinnsToken.balanceOf(address(this)) == MAX_TOKENS);
        stage = Stages.AuctionStarted;
        startItoTimestamp = block.timestamp;
        startPricePerToken = 2500;  //2500 cents is the starting price
        currentPerTokenPrice = startPricePerToken;
        }
        
    function ()
        public 
        payable 
        atStage(Stages.AuctionStarted)
        {
            require (msg.value >= minimumInvestment);
          
            if (((msg.value * priceFactor *100)/currentPerTokenPrice) >= (MAX_TOKENS - totalTokensSold) ||
            totalReceived >= 149000 * 10**18  //checks 46 million dollar hardcap considering 1 eth=300dollar
            )
                finalizeAuction();
                
              
            if((block.timestamp - startItoTimestamp) >=16 days)
            {
                currentPerTokenPrice = 150;
                finalizeAuction();
            }
                
            totalReceived += msg.value;       
            getCurrentPrice();
            setInvestment(msg.sender,msg.value);
        }
        
        function getCurrentPrice() public
        {
            totalTokensSold = ((totalReceived * priceFactor)/currentPerTokenPrice)*100;
            uint256 priceCalculationFactor = (block.timestamp - startItoTimestamp)/43200;
            if(priceCalculationFactor <=16)
            {
                currentPerTokenPrice = 2500 - (priceCalculationFactor * 100);
            }
            else if (priceCalculationFactor > 16 && priceCalculationFactor <= 31)
            {
                currentPerTokenPrice = 900 - (((priceCalculationFactor * 100) - 1600)/2);
            }
        }
        
        function setInvestment(address investor,uint amount) private 
        {
            if (currentPerTokenPrice >=1800)
            {
                goodwillBonusStatus[investor] = true;
                bonusTokens[investor] += (amount * priceFactor*100) / (currentPerTokenPrice);
                bonusRecipientCount++;   // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"Bonus days");
            }
            else if(currentPerTokenPrice < 1800)
            {
                itoBids[investor] += amount;     // will be used for ITO token distribution
                noBonusDays[investor] = amount;
                ito(investor,amount,"5th day or after");
            }
        }
        
        function finalizeAuction() private
        {
            uint256 leftTokens = MAX_TOKENS - totalTokensSold;
            finalPrice = currentPerTokenPrice;
            pinnsToken.burnLeftItoTokens(leftTokens);
            stage = Stages.AuctionEnded;
        }
        
        //Investor can claim his tokens within two weeks of ICO end using this function
        //It can be also used to claim on behalf of any investor
        function claimTokensICO(address receiver) public
        atStage(Stages.AuctionEnded)
        isValidPayload
        {
            if (receiver == 0)
            receiver = msg.sender;
            if(itoBids[receiver] >0)
            {
            uint256 tokenCount = (itoBids[receiver] * priceFactor*100) / (finalPrice);
            itoBids[receiver] = 0;
            pinnsToken.transfer(receiver, tokenCount);
            }
        }
        
       
        // goodwill tokens are sent to the contract by the owner
        function startGoodwillDistribution()
        external
        atStage(Stages.AuctionEnded)
        isOwner
        {
            require (pinnsToken.balanceOf(address(this)) != 0);
            stage = Stages.goodwillDistributionStarted;
        }
        // goodwill token need to be updated..
        function claimGoodwillTokens(address receiver)
        atStage(Stages.goodwillDistributionStarted)
        public
        isValidPayload
        {
            if (receiver == 0)
            receiver = msg.sender;
            if(goodwillBonusStatus[msg.sender] == true)
            {
                goodwillBonusStatus[msg.sender] = false;
                uint bonus = bonusTokens[msg.sender];
                pinnsToken.transfer(msg.sender, bonus);
            }
        }
        
        function drain() 
        external 
        isOwner
        atStage(Stages.AuctionEnded)
        {
            owner.transfer(this.balance);
        }
        
        //In case of emergency the state can be reset by the owner of the smart contract
        //Intention here is providing an extra protection to the Investor's funds
        // 1. AuctionDeployed,
        // 2. AuctionSetUp,
        // 3. AuctionStarted,
        // 4. AuctionEnded,
        // 5. goodwillDistributionStarted
        function setStage(uint state)
        external
        isOwner
        {
            if(state == 1)
            stage = Stages.AuctionDeployed;
            else if (state == 2)
            stage = Stages.AuctionSetUp;
            else if (state == 3)
            stage = Stages.AuctionStarted;
            else if (state == 4)
            stage = Stages.AuctionEnded;
            else if (state == 5)
            stage = Stages.goodwillDistributionStarted;
        }
    }
    
    