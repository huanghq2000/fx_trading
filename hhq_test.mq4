//+------------------------------------------------------------------+
//|                                                       hhq_test.mq4 |
//|                                   多指标综合交易策略 EA             |
//|                                   整合: BB + MA + MACD + RSI + STOCH |
//+------------------------------------------------------------------+
#property copyright   "hhq_test"
#property link        ""
#property description "Multi-Indicator Trading Strategy EA"
#property description "Indicators: Bollinger Bands, MA, MACD, RSI, Stochastic"
#property version     "1.00"
#property strict

//+------------------------------------------------------------------+
//| 枚举类型定义                                                       |
//+------------------------------------------------------------------+
enum ENUM_SIGNAL_MODE
  {
   ALL_MUST_AGREE = 0,    // 全部指标共振
   MAJORITY_VOTE  = 1,    // 多数指标一致（≥3个）
   WEIGHTED_SCORE = 2     // 加权评分制
  };

enum ENUM_MA_METHOD
  {
   MA_SMA = MODE_SMA,    // 简单移动平均
   MA_EMA = MODE_EMA,    // 指数移动平均
   MA_LWMA = MODE_LWMA,  // 线性加权移动平均
  };

//+------------------------------------------------------------------+
//| 输入参数 - 通用设置                                                |
//+------------------------------------------------------------------+
input double   Lots            = 0.2;          // 固定手数
input double   RiskPercent     = 2.0;          // 风险百分比（0=使用固定手数）
input double   TakeProfit      = 200;          // 止盈（点数）
input double   InitialStopLoss = 60;           // 止损（点数）
input double   TrailingStop    = 80;           // 移动止损距离（点数）
input double   MaxSpread       = 30;           // 最大允许点差
input int      MagicNumber     = 20250101;     // 魔术号
input ENUM_SIGNAL_MODE SignalMode = MAJORITY_VOTE; // 信号确认模式

//+------------------------------------------------------------------+
//| 输入参数 - Bollinger Bands                                         |
//+------------------------------------------------------------------+
input bool     UseBB           = true;         // 启用布林带
input int      BBPeriod        = 20;           // BB 周期
input double   BBDeviation     = 2.0;          // BB 标准差倍数
input int      BBShift         = 0;            // BB 偏移
input bool     BBRequireTouch  = true;         // 价格必须触及 BB 带

//+------------------------------------------------------------------+
//| 输入参数 - Moving Average                                          |
//+------------------------------------------------------------------+
input bool     UseMA           = true;         // 启用移动平均线
input int      MAFastPeriod    = 10;           // 快线 MA 周期
input int      MASlowPeriod    = 50;           // 慢线 MA 周期
input int      MAShift         = 0;            // MA 偏移
input ENUM_MA_METHOD MAMethod  = MA_EMA;       // MA 计算方法

//+------------------------------------------------------------------+
//| 输入参数 - MACD                                                     |
//+------------------------------------------------------------------+
input bool     UseMACD         = true;         // 启用 MACD
input int      MACDFastEMA     = 12;           // MACD 快 EMA
input int      MACDSlowEMA     = 26;           // MACD 慢 EMA
input int      MACDSignalSMA   = 9;            // MACD 信号线 SMA
input double   MACDOpenLevel   = 3.0;          // MACD 开仓最小幅度（点数）

//+------------------------------------------------------------------+
//| 输入参数 - RSI                                                      |
//+------------------------------------------------------------------+
input bool     UseRSI          = true;         // 启用 RSI
input int      RSIPeriod       = 14;           // RSI 周期
input int      RSIOversold     = 30;           // RSI 超卖水平
input int      RSIOverbought   = 70;           // RSI 超买水平

//+------------------------------------------------------------------+
//| 输入参数 - Stochastic                                               |
//+------------------------------------------------------------------+
input bool     UseStoch        = true;         // 启用随机指标
input int      StochKPeriod    = 5;            // K 线周期
input int      StochDPeriod    = 3;            // D 线周期
input int      StochSlowing    = 3;            // 慢速线
input int      StochOversold   = 20;           // 随机指标超卖水平
input int      StochOverbought = 80;           // 随机指标超买水平

//+------------------------------------------------------------------+
//| 输入参数 - 信号灵敏度系数（<1.0=收紧条件  >1.0=放宽条件）           |
//+------------------------------------------------------------------+
input double   BB_Sensitivity   = 2.0;         // BB 灵敏度（影响带宽范围）
input double   MA_Sensitivity   = 2.0;         // MA 灵敏度（影响交叉确认距离）
input double   MACD_Sensitivity = 2.0;         // MACD 灵敏度（影响开仓幅度要求）
input double   RSI_Sensitivity  = 1.5;         // RSI 灵敏度（影响超买超卖区间宽度）
input double   Stoch_Sensitivity = 2.0;        // Stoch 灵敏度（影响超买超卖区间宽度）

//+------------------------------------------------------------------+
//| 全局变量                                                           |
//+------------------------------------------------------------------+
double pipSize;
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- 计算 pipSize
   pipSize = (Digits == 3 || Digits == 5) ? Point * 10 : Point;

//--- 验证参数
   if(BBPeriod < 2)
     {
      Print("BBPeriod 必须 >= 2");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(MAFastPeriod >= MASlowPeriod)
     {
      Print("MAFastPeriod 必须 < MASlowPeriod");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(TakeProfit < 10)
     {
      Print("TakeProfit 必须 >= 10");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InitialStopLoss < 10)
     {
      Print("InitialStopLoss 必须 >= 10");
      return(INIT_PARAMETERS_INCORRECT);
     }

   Print("hhq_test EA 初始化成功");
   Print("指标启用状态: BB=", UseBB, " MA=", UseMA, " MACD=", UseMACD,
         " RSI=", UseRSI, " STOCH=", UseStoch);
   Print("信号模式: ", SignalMode == ALL_MUST_AGREE ? "全部共振" :
         SignalMode == MAJORITY_VOTE ? "多数投票" : "加权评分");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("hhq_test EA 已卸载");
  }

//+------------------------------------------------------------------+
//| OnTick - 主交易逻辑                                                 |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- 基础数据检查
   if(Bars < 100)
     {
      Print("bars 小于 100");
      return;
     }

//--- 点数检查
   if(TakeProfit < 10 || InitialStopLoss < 10)
     {
      Print("止盈或止损点数不足");
      return;
     }

//--- 点差检查
   double spread = Ask - Bid;
   if(spread > MaxSpread * Point)
      return;

//--- 仅在新 K 线的第一个 tick 执行交易逻辑
   if(Time[0] == lastBarTime)
      return;
   lastBarTime = Time[0];

//--- 获取所有指标信号
   int bbSignal    = GetBBSignal();
   int maSignal    = GetMASignal();
   int macdSignal  = GetMACDSignal();
   int rsiSignal   = GetRSISignal();
   int stochSignal = GetStochSignal();

//--- 综合买入/卖出信号
   int finalSignal = CombineSignals(bbSignal, maSignal, macdSignal, rsiSignal, stochSignal);

//--- 管理现有持仓
   int total = OrdersTotal();
   if(total > 0)
     {
      ManageOpenPositions();
      return;
     }

//--- 没有持仓时，检查新开仓信号
   if(total < 1)
     {
      if(AccountFreeMargin() < (1000 * Lots))
        {
         Print("保证金不足. Free Margin = ", AccountFreeMargin());
         return;
        }

      if(finalSignal == 1)
         OpenBuy();
      else if(finalSignal == -1)
         OpenSell();
     }
  }

//+------------------------------------------------------------------+
//| Bollinger Bands 信号计算                                           |
//| 返回: 1=买入, -1=卖出, 0=无信号                                     |
//+------------------------------------------------------------------+
int GetBBSignal()
  {
   if(!UseBB) return(0);

   //--- effective deviation scaled by sensitivity; >1 widens bands, <1 narrows
   double effDev = BBDeviation * BB_Sensitivity;

   double bbUpper = iBands(NULL, 0, BBPeriod, effDev, BBShift, PRICE_CLOSE, MODE_UPPER, 1);
   double bbLower = iBands(NULL, 0, BBPeriod, effDev, BBShift, PRICE_CLOSE, MODE_LOWER, 1);

   if(bbUpper == 0 || bbLower == 0) return(0);

   double closePrev = Close[1];
   double lowPrev   = Low[1];
   double highPrev  = High[1];
   double bandwidth = bbUpper - bbLower;

//--- 买入: 价格触及或跌破下轨
   if(BBRequireTouch)
     {
      if(lowPrev <= bbLower && closePrev > bbLower)
         return(1);
     }
   else
     {
      if(closePrev <= bbLower + bandwidth * 0.05)
         return(1);
     }

//--- 卖出: 价格触及或突破上轨
   if(BBRequireTouch)
     {
      if(highPrev >= bbUpper && closePrev < bbUpper)
         return(-1);
     }
   else
     {
      if(closePrev >= bbUpper - bandwidth * 0.05)
         return(-1);
     }

   return(0);
  }

//+------------------------------------------------------------------+
//| Moving Average 信号计算                                            |
//| 返回: 1=多头排列, -1=空头排列, 0=无信号                              |
//+------------------------------------------------------------------+
int GetMASignal()
  {
   if(!UseMA) return(0);

   double maFast  = iMA(NULL, 0, MAFastPeriod, MAShift, (int)MAMethod, PRICE_CLOSE, 1);
   double maSlow  = iMA(NULL, 0, MASlowPeriod, MAShift, (int)MAMethod, PRICE_CLOSE, 1);
   double maFast0 = iMA(NULL, 0, MAFastPeriod, MAShift, (int)MAMethod, PRICE_CLOSE, 0);
   double maSlow0 = iMA(NULL, 0, MASlowPeriod, MAShift, (int)MAMethod, PRICE_CLOSE, 0);

   if(maSlow == 0) return(0);

   //--- sensitivity: required percentage gap = baseGap / MA_Sensitivity
   double baseGap = maSlow * 0.001;  // 0.1% of price
   double requiredGap = baseGap / MathMax(MA_Sensitivity, 0.01);

//--- 金叉（买入信号）：快线在慢线上方且超过要求间距
   if(maFast > maSlow + requiredGap && maFast0 > maSlow0)
      return(1);

//--- 死叉（卖出信号）：快线在慢线下方且超过要求间距
   if(maFast < maSlow - requiredGap && maFast0 < maSlow0)
      return(-1);

//--- 价格相对于 MA 的位置作为辅助判断，也受灵敏度影响
   if(Close[1] > maSlow + requiredGap)
      return(1);
   if(Close[1] < maSlow - requiredGap)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| MACD 信号计算                                                      |
//| 返回: 1=买入, -1=卖出, 0=无信号                                     |
//+------------------------------------------------------------------+
int GetMACDSignal()
  {
   if(!UseMACD) return(0);

   double macdCurr    = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_MAIN, 0);
   double macdPrev    = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_MAIN, 1);
   double signalCurr  = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_SIGNAL, 0);
   double signalPrev  = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_SIGNAL, 1);

   //--- sensitivity: >1 lowers the threshold (easier), <1 raises it (harder)
   double effLevel = MACDOpenLevel / MathMax(MACD_Sensitivity, 0.01);

//--- 金叉（零轴下方更可靠）
   if(macdCurr > signalCurr && macdPrev <= signalPrev)
     {
      if(MathAbs(macdCurr) > effLevel * Point)
         return(1);
     }

//--- 死叉（零轴上方更可靠）
   if(macdCurr < signalCurr && macdPrev >= signalPrev)
     {
      if(MathAbs(macdCurr) > effLevel * Point)
         return(-1);
     }

//--- 柱状图方向
   if(macdCurr < 0 && macdCurr > macdPrev && macdCurr > signalCurr)
      return(1);   // 零轴下向上反转
   if(macdCurr > 0 && macdCurr < macdPrev && macdCurr < signalCurr)
      return(-1);  // 零轴上向下反转

   return(0);
  }

//+------------------------------------------------------------------+
//| RSI 信号计算                                                       |
//| 返回: 1=买入(超卖反弹), -1=卖出(超买回落), 0=无信号                  |
//+------------------------------------------------------------------+
int GetRSISignal()
  {
   if(!UseRSI) return(0);

   double rsiCurr = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, 0);
   double rsiPrev = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, 1);

   //--- sensitivity: >1 moves thresholds toward 50 (easier), <1 pushes them outward (harder)
   double effOversold   = 50 - (50 - RSIOversold)   / MathMax(RSI_Sensitivity, 0.01);
   double effOverbought = 50 + (RSIOverbought - 50) / MathMax(RSI_Sensitivity, 0.01);

//--- 超卖区域反弹（买入）
   if(rsiPrev < effOversold && rsiCurr > effOversold)
      return(1);
   if(rsiPrev < effOversold && rsiCurr > rsiPrev)
      return(1);

//--- 超买区域回落（卖出）
   if(rsiPrev > effOverbought && rsiCurr < effOverbought)
      return(-1);
   if(rsiPrev > effOverbought && rsiCurr < rsiPrev)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Stochastic 信号计算                                                |
//| 返回: 1=买入(超卖金叉), -1=卖出(超买死叉), 0=无信号                  |
//+------------------------------------------------------------------+
int GetStochSignal()
  {
   if(!UseStoch) return(0);

   double stochKCurr = iStochastic(NULL, 0, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, 0);
   double stochKPrev = iStochastic(NULL, 0, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, 1);
   double stochDCurr = iStochastic(NULL, 0, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, 0);
   double stochDPrev = iStochastic(NULL, 0, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_SIGNAL, 1);

   //--- sensitivity: >1 moves thresholds toward 50 (easier), <1 pushes them outward (harder)
   double effOversold   = 50 - (50 - StochOversold)   / MathMax(Stoch_Sensitivity, 0.01);
   double effOverbought = 50 + (StochOverbought - 50) / MathMax(Stoch_Sensitivity, 0.01);

//--- 超卖区域 K 上穿 D（买入）
   if(stochKCurr > stochDCurr && stochKPrev <= stochDPrev)
     {
      if(stochKPrev < effOversold || stochDPrev < effOversold)
         return(1);
     }

//--- 超买区域 K 下穿 D（卖出）
   if(stochKCurr < stochDCurr && stochKPrev >= stochDPrev)
     {
      if(stochKPrev > effOverbought || stochDPrev > effOverbought)
         return(-1);
     }

//--- 辅助：远离极端区域的方向
   if(stochKCurr < effOversold && stochKCurr > stochKPrev)
      return(1);
   if(stochKCurr > effOverbought && stochKCurr < stochKPrev)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| 综合信号判断                                                       |
//| 通过配置的信号模式处理各指标信号                                     |
//+------------------------------------------------------------------+
int CombineSignals(int bb, int ma, int macd, int rsi, int stoch)
  {
   int enabledCount = (UseBB ? 1 : 0) + (UseMA ? 1 : 0) +
                      (UseMACD ? 1 : 0) + (UseRSI ? 1 : 0) + (UseStoch ? 1 : 0);

//--- 至少要有2个指标启用
   if(enabledCount < 2)
     {
      Print("警告: 启用的指标少于2个，可能产生大量信号");
     }

   int signals[5];
   signals[0] = bb;
   signals[1] = ma;
   signals[2] = macd;
   signals[3] = rsi;
   signals[4] = stoch;

//--- 统计买入和卖出信号数
   int buyVotes = 0;
   int sellVotes = 0;

   for(int i = 0; i < 5; i++)
     {
      if(signals[i] == 1)  { buyVotes++; }
      if(signals[i] == -1) { sellVotes++; }
     }

//--- 根据信号模式判断
   switch(SignalMode)
     {
      case ALL_MUST_AGREE:
        // 所有启用的指标必须一致
        if(buyVotes == enabledCount)
           return(1);
        if(sellVotes == enabledCount)
           return(-1);
        break;

      case MAJORITY_VOTE:
        {
        // 过半数指标一致即可
        int majority = (enabledCount / 2) + 1;

        // 必须至少有一个趋势指标(MA)确认
        if(buyVotes >= majority && ma == 1)
           return(1);
        if(sellVotes >= majority && ma == -1)
           return(-1);

        // 即使 MA 未确认，若其他指标高度一致
        if(buyVotes >= enabledCount - 1 && buyVotes >= 3)
           return(1);
        if(sellVotes >= enabledCount - 1 && sellVotes >= 3)
           return(-1);
        break;
        }

      case WEIGHTED_SCORE:
        {
        // MA趋势权重×2, MACD×1.5, BB×1, RSI×1, Stoch×1
        double score = ma * 2.0 + macd * 1.5 + bb + rsi + stoch;

        if(score >= 3.5)  return(1);   // 强力买入
        if(score <= -3.5) return(-1);  // 强力卖出
        break;
        }
     }

   return(0);
  }

//+------------------------------------------------------------------+
//| 开仓：买入                                                         |
//+------------------------------------------------------------------+
void OpenBuy()
  {
   double sl = Ask - InitialStopLoss * pipSize;
   double tp = Ask + TakeProfit * pipSize;

//--- 风险百分比资金管理
   double lotSize = Lots;
   if(RiskPercent > 0)
     {
      double riskAmount = AccountEquity() * RiskPercent / 100.0;
      double riskPerLot = InitialStopLoss * pipSize * MarketInfo(Symbol(), MODE_TICKVALUE);
      if(riskPerLot > 0)
        {
         lotSize = NormalizeDouble(riskAmount / riskPerLot, 2);
         lotSize = MathMax(lotSize, MarketInfo(Symbol(), MODE_MINLOT));
         lotSize = MathMin(lotSize, MarketInfo(Symbol(), MODE_MAXLOT));
        }
     }

   int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 3, sl, tp, "hhq_test", MagicNumber, 0, Green);
   if(ticket > 0)
     {
      Print("买入开仓成功 | 价格: ", Ask, " SL: ", sl, " TP: ", tp, " 手数: ", lotSize);
     }
   else
     {
      Print("买入开仓失败: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| 开仓：卖出                                                         |
//+------------------------------------------------------------------+
void OpenSell()
  {
   double sl = Bid + InitialStopLoss * pipSize;
   double tp = Bid - TakeProfit * pipSize;

//--- 风险百分比资金管理
   double lotSize = Lots;
   if(RiskPercent > 0)
     {
      double riskAmount = AccountEquity() * RiskPercent / 100.0;
      double riskPerLot = InitialStopLoss * pipSize * MarketInfo(Symbol(), MODE_TICKVALUE);
      if(riskPerLot > 0)
        {
         lotSize = NormalizeDouble(riskAmount / riskPerLot, 2);
         lotSize = MathMax(lotSize, MarketInfo(Symbol(), MODE_MINLOT));
         lotSize = MathMin(lotSize, MarketInfo(Symbol(), MODE_MAXLOT));
        }
     }

   int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 3, sl, tp, "hhq_test", MagicNumber, 0, Red);
   if(ticket > 0)
     {
      Print("卖出开仓成功 | 价格: ", Bid, " SL: ", sl, " TP: ", tp, " 手数: ", lotSize);
     }
   else
     {
      Print("卖出开仓失败: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| 持仓管理（平仓 + 移动止损）                                         |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
     {
      if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      //--- 检查平仓信号
      if(CheckCloseSignal(orderType))
        {
         double closePrice = (orderType == OP_BUY) ? Bid : Ask;
         if(OrderClose(OrderTicket(), OrderLots(), closePrice, 3, White))
            Print("信号平仓成功 | Ticket: ", OrderTicket());
         else
            Print("平仓失败: ", GetLastError());
         continue;
        }

      //--- 移动止损
      if(TrailingStop > 0)
         ApplyTrailingStop(orderType);
     }
  }

//+------------------------------------------------------------------+
//| 检查平仓信号                                                       |
//+------------------------------------------------------------------+
bool CheckCloseSignal(int orderType)
  {
//--- MACD 反转作为平仓信号
   if(UseMACD)
     {
      double macdCurr   = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_MAIN, 1);
      double macdPrev   = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_MAIN, 2);
      double signalCurr = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_SIGNAL, 1);
      double signalPrev = iMACD(NULL, 0, MACDFastEMA, MACDSlowEMA, MACDSignalSMA, PRICE_CLOSE, MODE_SIGNAL, 2);

      if(orderType == OP_BUY)
        {
         if(macdCurr < signalCurr && macdPrev >= signalPrev) // 死叉平多
            return(true);
        }
      else
        {
         if(macdCurr > signalCurr && macdPrev <= signalPrev) // 金叉平空
            return(true);
        }
     }

//--- 价格回到布林带中轨作为平仓信号
   if(UseBB)
     {
      double bbMid = iBands(NULL, 0, BBPeriod, BBDeviation, BBShift, PRICE_CLOSE, MODE_MAIN, 1);
      if(orderType == OP_BUY && Close[1] >= bbMid)
         return(true);
      if(orderType == OP_SELL && Close[1] <= bbMid)
         return(true);
     }

//--- RSI 回到中性区域
   if(UseRSI)
     {
      double rsiCurr = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, 1);
      if(orderType == OP_BUY && rsiCurr > 50)
         return(true);
      if(orderType == OP_SELL && rsiCurr < 50)
         return(true);
     }

//--- Stoch 回到中性区域
   if(UseStoch)
     {
      double stochK = iStochastic(NULL, 0, StochKPeriod, StochDPeriod, StochSlowing, MODE_SMA, 0, MODE_MAIN, 1);
      if(orderType == OP_BUY && stochK > 50)
         return(true);
      if(orderType == OP_SELL && stochK < 50)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| 移动止损                                                           |
//+------------------------------------------------------------------+
void ApplyTrailingStop(int orderType)
  {
   double newSL = 0;
   double currentSL = OrderStopLoss();
   double openPrice = OrderOpenPrice();

   if(orderType == OP_BUY)
     {
      double trailLevel = Bid - TrailingStop * pipSize;
      if(trailLevel <= openPrice)
         return;  // 未达到移动止损启动条件

      newSL = trailLevel;
      //--- 只有在新SL比当前SL更高时才修改
      if(currentSL == 0 || newSL > currentSL + pipSize * TrailingStop / 3)
        {
         if(!OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, Green))
            Print("移动止损修改失败(买入): ", GetLastError());
        }
     }
   else if(orderType == OP_SELL)
     {
      double trailLevel = Ask + TrailingStop * pipSize;
      if(trailLevel >= openPrice)
         return;  // 未达到移动止损启动条件

      newSL = trailLevel;
      //--- 只有在新SL比当前SL更低时才修改
      if(currentSL == 0 || newSL < currentSL - pipSize * TrailingStop / 3)
        {
         if(!OrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, Red))
            Print("移动止损修改失败(卖出): ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
