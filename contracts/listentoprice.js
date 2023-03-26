const Kucoin = require('kucoin-api');

const api = new Kucoin({
  apiKey: 'your-api-key',
  secretKey: 'your-secret-key',
  passphrase: 'your-passphrase'
});

const symbol = 'BTC-USDT';
const basePrice = 30000;
const priceIncrement = 100;

async function listToken() {
  try {
    // Get current ticker price
    const ticker = await api.getTicker(symbol);
    const currentPrice = parseFloat(ticker.price);

    // Calculate listing price
    const listingPrice = currentPrice + priceIncrement;

    // Check if current price is equal or above base price
    if (currentPrice >= basePrice) {
      // List token on spot trading platform
      const result = await api.createLimitOrder(symbol, 'SELL', listingPrice, 0.01);
      console.log(result);
    }
  } catch (err) {
    console.log(err);
  }
}

// Continuously check price and list token
setInterval(listToken, 5000); // Check every 5 seconds
