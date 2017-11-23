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
    uint public ceiling;
    uint public priceFactor;
  
  
    /*
     *  Store to maintain the status and details of the investors,
     *  who invest in first four days for distributing goodwill bonus tokens
     */
    
    uint public day1Count;
    uint public day2Count;
    uint public day3Count;
    uint public day4Count;
    
    uint public day1Bonus;
    uint public day2Bonus;
    uint public day3Bonus;
    uint public day4Bonus;
    
    mapping (address => bool) public statusDay1; 
    mapping (address => bool) public statusDay2;
    mapping (address => bool) public statusDay3;
    mapping (address => bool) public statusDay4;
    
     /*
     *  Variables to store the total amount recieved per day
     */
    uint public day1Recieved;
    uint public day2Recieved;
    uint public day3Recieved;
    uint public day4Recieved;
    uint public totalReceived;
    


    uint public startItoTimestamp; // to store the starting time of the ITO
    uint public pricePerToken;
    uint public startPricePerToken;
    uint public currentPerTokenPrice;   
    uint public finalPrice;
    uint public totalTokensSold;
    
    mapping (address => uint) public noBonusDays;
    mapping (address => uint) public itoBids;
    event ito(address investor, uint amount, string day);
    
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
    
    function pinnsDutchAuction(uint EtherPriceFactor)
        public
    {
        if (EtherPriceFactor == 0)
            // price Argument is null.
            revert();
        owner = msg.sender;
        stage = Stages.AuctionDeployed;
        priceFactor = EtherPriceFactor;
       
    }
    
     /// @dev Setup function sets external contracts' addresses.
    function start_ICO(address toknn_) external isOwner atStage(Stages.AuctionDeployed)
    {
      if (pinnsToken.balanceOf(this) != MAX_TOKENS)
            revert();
            
        pinnsToken = PocketinnsToken(toknn_);
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
            if (msg.value < minimumInvestment || 
            ((msg.value * priceFactor *100)/currentPerTokenPrice) >= (MAX_TOKENS - totalTokensSold) ||
            totalReceived >= 149000 * 10**18  //checks 46 million dollar hardcap considering 1 eth=300dollar
            )
            revert();
            totalReceived += msg.value;       
            getCurrentPrice();
            setInvestment(msg.sender,msg.value);
        }
        
        function getCurrentPrice() public
        {
            totalTokensSold = ((totalReceived * priceFactor)/currentPerTokenPrice)*100;
            uint priceCalculationFactor = (block.timestamp - startItoTimestamp)/432;
            if(priceCalculationFactor <=1600)
            {
                currentPerTokenPrice = 2500 - priceCalculationFactor;
            }
            else if (priceCalculationFactor > 1600 && priceCalculationFactor <= 3100)
            {
                currentPerTokenPrice = 900 - ((priceCalculationFactor - 1600)/2);
            }
        }
        
        function setInvestment(address investor,uint amount) private 
        {
            if (currentPerTokenPrice == 2500 || currentPerTokenPrice == 2400)
            {
                statusDay1[investor] = true;
                day1Count++;   // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 1");
            }
            else if ((currentPerTokenPrice == 2300 || currentPerTokenPrice == 2200))
            {
                statusDay2[investor] = true;
                day2Count++;    // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 2");
            }
            else if((currentPerTokenPrice == 2100 || currentPerTokenPrice == 2000))
            {
                statusDay3[investor] = true;
                day3Count++;        // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 3");
            }
            else if((currentPerTokenPrice == 1900 || currentPerTokenPrice == 1800))
            {
                statusDay4[investor] = true;
                day4Count++;        // will be used later for goodwill token distribution
                itoBids[investor] += amount;     // will be used for ITO token distribution
                ito(investor,amount,"day 4");
            }
            else if(currentPerTokenPrice < 1800)
            {
                if((block.timestamp - startItoTimestamp) >=16 days)
                finalizeAuction();
                itoBids[investor] += amount;     // will be used for ITO token distribution
                noBonusDays[investor] = amount;
                ito(investor,amount,"5th day or after");
            }
        }
        
        function finalizeAuction() private
        {
            uint leftTokens = MAX_TOKENS - totalTokensSold;
            finalPrice = currentPerTokenPrice;
            pinnsToken.burnLeftItoTokens(leftTokens);
            stage = Stages.AuctionEnded;
        }
        
        //Investor can claim his tokens within two weeks of ICO end using this function
        //It can be also used to claim on behalf of any investor
        function claimTokensICO(address receiver) public
        atStage(Stages.AuctionEnded)
        {
            if (receiver == 0)
            receiver = msg.sender;
            if(itoBids[receiver] >0)
            {
            uint tokenCount = (itoBids[receiver] * priceFactor) / (finalPrice);
            itoBids[receiver] = 0;
            pinnsToken.transfer(receiver, tokenCount);
            }
        }
        
        
        //After 2 weeks owner will start godwill token distribution and will ensure that 
        //5 million goodwill tokens are sent to the contract
        function startGoodwillDistribution()
        public
        atStage(Stages.AuctionEnded)
        isOwner
        {
            if (pinnsToken.balanceOf(this) != goodwillTokensAmount)
            revert();
            
            day1Bonus = (3000000 * 10 **18)/day1Count;
            day2Bonus = (1000000 * 10 **18)/day2Count;
            day3Bonus = (750000 * 10 **18)/day3Count;
            day4Bonus = (250000 * 10 **18)/day4Count;
            stage = Stages.goodwillDistributionStarted;
        }
        
        function claimGoodwillTokens()
        atStage(Stages.goodwillDistributionStarted)
        public
        {
            if(statusDay1[msg.sender] == true)
            {
                statusDay1[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day1Bonus);
            }
            if(statusDay2[msg.sender] == true)
            {
                statusDay2[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day2Bonus);
            }
            if(statusDay3[msg.sender] == true)
            {
                statusDay3[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day3Bonus);
            }
            if(statusDay4[msg.sender] == true)
            {
                statusDay4[msg.sender] = false;
                pinnsToken.transfer(msg.sender, day4Bonus);
            }
        }
    }