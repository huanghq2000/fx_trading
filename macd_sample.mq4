//+------------------------------------------------------------------+
//|                                                  MACD Sample.mq4 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                              http://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright   "2000-2026, MetaQuotes Ltd."
#property link        "https://www.mql5.com"

input double TakeProfit     = 50;   // 固定止盈点数
input double InitialStopLoss = 80;   // 初始止损点数（新增）
input double Lots           = 0.1;  // 固定手数
input double TrailingStop   = 30;   // 移动止损距离
input double MACDOpenLevel  = 3;    // 开仓MACD最小幅度
input double MACDCloseLevel = 2;    // 平仓MACD最小幅度
input int    MATrendPeriod  = 26;   // 趋势过滤EMA周期
input double MaxSpread      = 30;   // 最大允许点差（新增）
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   double MacdCurrent,MacdPrevious;
   double SignalCurrent,SignalPrevious;
   double MaCurrent,MaPrevious;
   double sl,tp,spread,NewSL,pipSize;
   int    cnt,ticket,total;
//---
// initial data checks
//---
   if(Bars<100)
     {
      Print("bars less than 100");
      return;
     }
   if(TakeProfit<10)
     {
      Print("TakeProfit less than 10");
      return;
     }
   if(InitialStopLoss<10)
     {
      Print("InitialStopLoss less than 10");
      return;
     }

//--- compute pip size: adapts to 4-digit and 5-digit brokers automatically
   pipSize = (Digits == 3 || Digits == 5) ? Point * 10 : Point;

//--- check spread before trading (new risk protection)
   spread = Ask - Bid;
   if(spread > MaxSpread * Point)
     {
      // spread too wide, skip this tick
      return;
     }

//--- only trade on first tick of a new bar (new risk protection)
//    prevents multiple signals and order modifications within the same candle
   static datetime lastBarTime = 0;
   if(Time[0] == lastBarTime)
      return;
   lastBarTime = Time[0];

//--- to simplify the coding and speed up access data are put into internal variables
   MacdCurrent   = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
   MacdPrevious  = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
   SignalCurrent = iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);
   SignalPrevious= iMACD(NULL,0,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
   MaCurrent     = iMA(NULL,0,MATrendPeriod,0,MODE_EMA,PRICE_CLOSE,0);
   MaPrevious    = iMA(NULL,0,MATrendPeriod,0,MODE_EMA,PRICE_CLOSE,1);

   total=OrdersTotal();
   if(total<1)
     {
      //--- no opened orders identified
      if(AccountFreeMargin()<(1000*Lots))
        {
         Print("We have no money. Free Margin = ",AccountFreeMargin());
         return;
        }
      //--- check for long position (BUY) possibility
      if(MacdCurrent<0 && MacdCurrent>SignalCurrent && MacdPrevious<SignalPrevious &&
         MathAbs(MacdCurrent)>(MACDOpenLevel*Point) && MaCurrent>MaPrevious)
        {
         //--- set initial stop loss (new risk protection)
         sl = Ask - InitialStopLoss * pipSize;
         tp = Ask + TakeProfit * pipSize;
         ticket=OrderSend(Symbol(),OP_BUY,Lots,Ask,3,sl,tp,"macd sample",16384,0,Green);
         if(ticket>0)
           {
            if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
               Print("BUY order opened : ",OrderOpenPrice()," SL:",sl," TP:",tp);
           }
         else
            Print("Error opening BUY order : ",GetLastError());
         return;
        }
      //--- check for short position (SELL) possibility
      if(MacdCurrent>0 && MacdCurrent<SignalCurrent && MacdPrevious>SignalPrevious &&
         MacdCurrent>(MACDOpenLevel*Point) && MaCurrent<MaPrevious)
        {
         //--- set initial stop loss (new risk protection)
         sl = Bid + InitialStopLoss * pipSize;
         tp = Bid - TakeProfit * pipSize;
         ticket=OrderSend(Symbol(),OP_SELL,Lots,Bid,3,sl,tp,"macd sample",16384,0,Red);
         if(ticket>0)
           {
            if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
               Print("SELL order opened : ",OrderOpenPrice()," SL:",sl," TP:",tp);
           }
         else
            Print("Error opening SELL order : ",GetLastError());
        }
      //--- exit from the "no opened orders" block
      return;
     }
//--- it is important to enter the market correctly, but it is more important to exit it correctly...
   for(cnt=0;cnt<total;cnt++)
     {
      if(!OrderSelect(cnt,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderType()<=OP_SELL &&   // check for opened position
         OrderSymbol()==Symbol())  // check for symbol
        {
         //--- long position is opened
         if(OrderType()==OP_BUY)
           {
            //--- should it be closed by MACD signal?
            if(MacdCurrent>0 && MacdCurrent<SignalCurrent && MacdPrevious>SignalPrevious &&
               MacdCurrent>(MACDCloseLevel*Point))
              {
               //--- close order and exit
               if(!OrderClose(OrderTicket(),OrderLots(),Bid,3,Violet))
                  Print("OrderClose error ",GetLastError());
               return;
              }
            //--- check for trailing stop
            if(TrailingStop>0)
              {
               if(Bid-OrderOpenPrice()>pipSize*TrailingStop)
                 {
                  NewSL = Bid - pipSize * TrailingStop;
                  //--- only modify if SL improves meaningfully (avoids Error 1 from micro-moves)
                  if(OrderStopLoss()==0 || OrderStopLoss()<NewSL-pipSize*TrailingStop/3)
                    {
                     //--- modify order and exit
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),NewSL,OrderTakeProfit(),0,Green))
                        Print("OrderModify error ",GetLastError());
                     return;
                    }
                 }
              }
           }
         else // go to short position
           {
            //--- should it be closed by MACD signal?
            if(MacdCurrent<0 && MacdCurrent>SignalCurrent &&
               MacdPrevious<SignalPrevious && MathAbs(MacdCurrent)>(MACDCloseLevel*Point))
              {
               //--- close order and exit
               if(!OrderClose(OrderTicket(),OrderLots(),Ask,3,Violet))
                  Print("OrderClose error ",GetLastError());
               return;
              }
            //--- check for trailing stop
            if(TrailingStop>0)
              {
               if((OrderOpenPrice()-Ask)>(pipSize*TrailingStop))
                 {
                  NewSL = Ask + pipSize * TrailingStop;
                  //--- only modify if SL improves meaningfully (avoids Error 1 from micro-moves)
                  if(OrderStopLoss()==0 || OrderStopLoss()>NewSL+pipSize*TrailingStop/3)
                    {
                     //--- modify order and exit
                     if(!OrderModify(OrderTicket(),OrderOpenPrice(),NewSL,OrderTakeProfit(),0,Red))
                        Print("OrderModify error ",GetLastError());
                     return;
                    }
                 }
              }
           }
        }
     }
//---
  }
//+------------------------------------------------------------------+
