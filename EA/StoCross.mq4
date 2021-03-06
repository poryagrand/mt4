#property copyright "Copyright 2017, Victor"

#include <hash.mqh>

#define MAGIC_NUM 20171218


#define STO_BELOW_50 -1
#define STO_ABOVE_50 1

#define STOCROSS_OPEN_BUY_SIGNAL 1
#define STOCROSS_OPEN_SELL_SIGNAL -1
#define STOCROSS_NO_SIGNAL 0

#define BUY_ORDER_CLOSE 1
#define SELL_ORDER_CLOSE 2


string GBPUSD = "GBPUSD";
string EURUSD = "EURUSD";
string USDJPY = "USDJPY";
string USDCAD = "USDCAD";
string AUDUSD = "AUDUSD";

static int MaxOrders = 4;
extern double MaxRisk = 1;//资金风险1=1%

//--- input parameters

extern int       ShortMaPeriod = 10;
extern int       LongMaPeriod  = 20;


Hash *map = new Hash();
bool ProcedTrailing = true; // 是否启动移动止损止盈
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum STATE
  {
   BULL,
   BEAR,
   SWING
  };


double getLotsOptimized(double RiskValue)
  {
   //最大可开仓手数  最好用净值 不要用余额
   double iLots=NormalizeDouble((AccountBalance()*RiskValue/100/MarketInfo(Symbol(),MODE_MARGINREQUIRED)),2);

   if(iLots<0.01)
     {
      iLots=0;
      Print("保证金余额不足");
     }

   return iLots;
   
  }
  
int getStopLoss(string symbol) {
   if(Period() == PERIOD_H1) {
      return getStopLoss_m(symbol);
   } else {
      return getStopLoss_s(symbol);
   }
}

int getTakeProfit(string symbol) {
   if(Period() == PERIOD_H1) {
      return getTakeProfit_m(symbol);
   } else {
      return getTakeProfit_s(symbol);
   }
}
  
/**
   获取不同货币对止损(短线交易)
 */
int getStopLoss_s(string symbol)
  {
   int stopLoss = 20;
   if(symbol==GBPUSD || symbol==USDCAD)
     {
      stopLoss = 20;
     }

   return stopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止盈(短线交易)
 */
int getTakeProfit_s(string symbol)
  {
   int takeprofit = 30;
   if(symbol==GBPUSD || symbol==USDCAD)
     {
      takeprofit = 30;
     }

   return takeprofit;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止损(中线交易)
 */
int getStopLoss_m(string symbol)
  {
   int stopLoss=40;
   if(symbol==GBPUSD || symbol==USDCAD)
     {
      stopLoss=40;
     }

   return stopLoss;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/**
   获取不同货币对止损(中线交易)
 */
int getTakeProfit_m(string symbol)
  {
   int takeprofit=60;
   if(symbol==EURUSD || symbol==GBPUSD || symbol==USDJPY)
     {
      takeprofit=60;
     }

   return takeprofit;
  }



// 两位或三位的报价 返回0.01 四位或五位报价 返回0.0001
double getPipPoint(string Currency)
  {
   int digits=(int)MarketInfo(Currency,MODE_DIGITS);
   double pips=0.0001;
   if(digits==2 || digits==3)
      pips=0.01;
   else if(digits==4 || digits==5)
      pips=0.0001;
   return pips;
  }
  
 /**
 *  返回值 :
 *      -1 - 下单失败 0 - 订单已存在 其它 - 订单号 
 */
int iOpenOrders(string myType,double myLots,int myLossStop,int myTakeProfit,string comment)
  {

   double UsePoint = getPipPoint(Symbol());

   int ticketNo = -1;
   int mySpread = MarketInfo(Symbol(),MODE_SPREAD);//点差 手续费 市场滑点
   double sl_buy =(myLossStop<=0)?0:(Ask-myLossStop*UsePoint);
   double tp_buy =(myTakeProfit<=0)?0:(Ask+myTakeProfit*UsePoint);
   double sl_sell=(myLossStop<=0)?0:(Bid+myLossStop*UsePoint);
   double tp_sell=(myTakeProfit<=0)?0:(Bid-myTakeProfit*UsePoint);

   if(myType=="Buy")
      ticketNo=OrderSend(Symbol(),OP_BUY,myLots,Ask,mySpread,sl_buy,tp_buy,comment);
   if(myType=="Sell")
      ticketNo=OrderSend(Symbol(),OP_SELL,myLots,Bid,mySpread,sl_sell,tp_sell,comment);

   return ticketNo;
  }
  

int checkStoSignal() {
   int signal = STOCROSS_NO_SIGNAL;
   
   // Execute only on the first tick of a new bar, to avoid repeatedly
   // opening orders when an open condition is satisfied.
   if (Volume[0] > 1) return(0);
   
   double sto[3]; 
   
   for(int i = 0; i < 3; i++) {
      sto[i] = iStochastic(NULL, 0, 144, 3, 3, MODE_EMA, 1, 0, i);
   }
   
   // 空单
   if(sto[2] >= 50 && sto[1] < 50) {
      signal = STOCROSS_OPEN_SELL_SIGNAL;
   }
   
   // 多单
   if(sto[2] <= 50 && sto[1] > 50) {
      signal  = STOCROSS_OPEN_BUY_SIGNAL;
   }
   
   return signal;
   
}

/**
 * 检查出场信号
 */
int checkExitSignal() {
   int signal = STOCROSS_NO_SIGNAL;
   
   double sto[3]; 
   STATE cur, prev;
   
   for(int i = 0; i < 3; i++) {
      sto[i] = iStochastic(NULL, 0, 144, 3, 3, MODE_EMA, 1, 0, i);
   }
   
   // 多单出场
   if(sto[2] >= 20 && sto[1] < 20) {
      cur = getTrend(0, Period());
      prev = getTrend(1, Period());
      
      if(cur == BEAR && prev == BEAR) {
         signal = BUY_ORDER_CLOSE;
      }
     
   }
   
   // 空单出场
   if(sto[2] <= 20 && sto[1] > 20) {
      cur = getTrend(0, Period());
      prev = getTrend(1, Period());
      
      if(cur == BULL && prev == BULL) {
         signal  = SELL_ORDER_CLOSE;
      }
     
   }
   
   return signal;   
}


//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//----

   
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//----
   delete map;
//----
   return(0);
  }
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+

  int getOrderCount(string symbol)
  {
   int count = 0;
//---
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) break;
      if(OrderSymbol()==Symbol())
        {
         count++;
        }
     }
//--- return orders volume
   return count;
  }

int start()
  {
//----
   
   
   
   shortTermTrading();
     
//----
   return(0);
  }
//+------------------------------------------------------------------+

void shortTermTrading() {

   bool flag=Symbol()== EURUSD || Symbol() == GBPUSD || 
             Symbol()== USDJPY || Symbol() == AUDUSD;

   if(!flag) return;
   
   int stopLoss=30;
   int takeProfit=40;
   double lots=0.0;
   double discrimination=0.0;
   int orderCount = 0;
   
   
   if(ProcedTrailing) {
      ProcessTrailing();
   }
   
   // 检查交易信号
   int signal = checkStoSignal();
   
   int cnt = 0;
   cnt = getOrderCount(Symbol());
   if(cnt > 0) {
      // 检查出场信号
      int exitSignal = checkExitSignal();
      if(exitSignal == BUY_ORDER_CLOSE) {
         iCloseOrders("Buy");
      } else if(exitSignal == SELL_ORDER_CLOSE) {
         iCloseOrders("Sell");
      }
   }
   
   
   STATE cur, prev;
   
   // 上穿 买入信号
   if (signal == STOCROSS_OPEN_BUY_SIGNAL)
     {
      
      cur = getTrend(0, Period()); 
      prev = getTrend(1,Period());
           
      if((cur == BULL) && (prev == BULL)) {
      
         stopLoss=getStopLoss(Symbol());
         takeProfit=getTakeProfit(Symbol());
         lots = getLotsOptimized(MaxRisk);
      
         iOpenOrders("Buy",lots,stopLoss,takeProfit,Symbol());
      }
      
      
     
     }
   // 下穿 卖出信号
   else if (signal == STOCROSS_OPEN_SELL_SIGNAL)
     {
      
      cur = getTrend(0, Period()); 
      prev = getTrend(1, Period());
      
       
      if((cur == BEAR) && (prev == BEAR)) {
      
         stopLoss=getStopLoss(Symbol());
         takeProfit=getTakeProfit(Symbol());
         lots = getLotsOptimized(MaxRisk);
      
         iOpenOrders("Sell",lots,stopLoss,takeProfit,Symbol());
      }
     }
   
}


void iCloseOrders(string myType)
  {
   int cnt=OrdersTotal();
   int i;
//选择当前持仓单
   if(OrderSelect(cnt-1,SELECT_BY_POS)==false)return;
   if(myType=="All")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError()); 
           }
        }
     }
   else if(myType=="Buy")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else if(OrderType()==OP_BUY && OrderSymbol() == Symbol()) {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
            Print("关闭买单");
           }
        }
     }
   else if(myType=="Sell")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS) == false)continue;
         else if((OrderType() == OP_SELL) && (OrderSymbol() == Symbol())){
            
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
            Print("关闭卖单");
         }
        }
     }
   else if(myType=="Profit")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else if(OrderProfit()>0){
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
         }
        }
     }
   else if(myType=="Loss")
     {
      for(i=cnt-1;i>=0;i--)
        {
         if(OrderSelect(i,SELECT_BY_POS)==false)continue;
         else if(OrderProfit()<0) {
            if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),0))
               Print("OrderClose error ",GetLastError());
         }
        }
     }
  }
  
  
  STATE getTrend(int index, int timeframe) 
  {
   STATE state=SWING;

   double MA10=iMA(Symbol(),timeframe,10,0,MODE_EMA,PRICE_CLOSE,index);
   double MA20=iMA(Symbol(),timeframe,20,0,MODE_EMA,PRICE_CLOSE,index);


// 计算基准线Kijun-sen
   double kijunsen=iIchimoku(Symbol(),timeframe,9,26,52,MODE_KIJUNSEN,index);
   double tenkansen=iIchimoku(Symbol(),timeframe,9,26,52,MODE_TENKANSEN,index);

   double close=iClose(Symbol(),timeframe,index);

   if(close>=kijunsen && tenkansen>=kijunsen)
     {
      if(close >= MA10 && close >= MA20)
        {
         state=BULL;
        }
     } else if(close<kijunsen && tenkansen<kijunsen) {
      if(close<MA10 && close<MA20)
        {
         state=BEAR;
        }
        } else {
         state=SWING;
     }

   return state;
  }
  

  
  /**
   *  移动止损
   */

void ProcessTrailing() 
  {
   int initTrailing = 20;
   double stoploss ;
   double takeprofit;
   double pip = getPipPoint(Symbol());
   string orderTicket = "";
   int trail = -1;
   for(int i=0;i<OrdersTotal();i++)
     {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
        {
         if((OrderType()==OP_BUY) && (Symbol()==OrderSymbol()))
           {
            stoploss = OrderStopLoss();
            takeprofit = OrderTakeProfit();
            
            orderTicket = IntegerToString(OrderTicket());
            
            trail = map.hGetInt(orderTicket);
            if(trail == -1) {
               trail = initTrailing;
               stoploss += initTrailing * pip;
               
            } else if(trail >= initTrailing) {
               return;
               trail += 10;
               stoploss += 5 * pip;
            } else {
             return;
            }
            
           // takeprofit += 5 * pip;
            
            if(((Bid - OrderOpenPrice())/pip) >= trail)
              {
               
               if(OrderModify(OrderTicket(),OrderOpenPrice(),stoploss,takeprofit,0)==true)
                 {
                  Print("Order: ", OrderTicket(), "New stoploss:", stoploss);
                  map.hPutInt(orderTicket, trail);
                 }
              }
           }
         if((OrderType()==OP_SELL) && ((Symbol()==OrderSymbol())))
           {
            stoploss = OrderStopLoss();
            takeprofit = OrderTakeProfit();
            orderTicket = IntegerToString(OrderTicket());
            
            trail = map.hGetInt(orderTicket);
            if(trail == -1) {
               trail = initTrailing;
               stoploss -= initTrailing * pip;
               
            } else if(trail >= initTrailing) {
               return;
               trail += 10;
               stoploss -= 5 * pip;
            } else {
                  return;
            }
          //  takeprofit -= 5 * pip;
            
            if(((OrderOpenPrice()-Ask)/pip) >= trail)
              {
               double sellsl = OrderStopLoss();
               if(OrderModify(OrderTicket(),OrderOpenPrice(),stoploss,takeprofit,0) == true)
                 {
                  Print("Order: ", OrderTicket(), "New stoploss:", stoploss);
                  map.hPutInt(orderTicket, trail);
                 }
              }
           }
        }
     }

  }