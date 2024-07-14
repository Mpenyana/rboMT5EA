//+------------------------------------------------------------------+
//|                                                          RBO.mq5 |
//|                                Copyright 2024, EN3 Technologies. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, EN3 Technologies."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

CTrade trade;

input string RangeTimeStart = "00:00";
input string RangeTimeEnd = "07:00";
input string endTradeTime = "23:00";
input long Magic = 333;

bool endOfRange = false;
bool rangeStarted = false;
bool allowTrades = false;

double highestPricePoint = NormalizeDouble(0, _Digits);
double lowestPricePoint = NormalizeDouble(-1, _Digits);

int barsSinceStartOfRange = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   Print(OrdersTotal());
   datetime currentBarOpeningTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   string time = TimeToString(currentBarOpeningTime, TIME_MINUTES);
   
   if(!rangeStarted) {
      if(RangeTimeStart == time) {
         rangeStarted = true;
         allowTrades = true;
         endOfRange = false;
      }
   } else {
      //initialize lowest and highest price points @ the beg of range:
      int firstBarIndex = iBarShift(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart), true);
      if(firstBarIndex == 0) {
         highestPricePoint = iHigh(_Symbol, PERIOD_CURRENT, firstBarIndex);
         lowestPricePoint = iLow(_Symbol, PERIOD_CURRENT, firstBarIndex);
      }
      
      if(Bars(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart), StringToTime(RangeTimeEnd)) >
         barsSinceStartOfRange) {
            barsSinceStartOfRange = Bars(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart),
               StringToTime(RangeTimeEnd));
            int prevBarHigh = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, barsSinceStartOfRange, 1);
            int prevBarLow = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, barsSinceStartOfRange, 1);
            
            double prevBarHighPrice = iHigh(_Symbol, PERIOD_CURRENT, prevBarHigh);
            double prevBarLowPrice = iLow(_Symbol, PERIOD_CURRENT, prevBarLow);
            
            if(prevBarHighPrice > highestPricePoint) {
               highestPricePoint = prevBarHighPrice;
            }
            if(prevBarLowPrice < lowestPricePoint) {
               lowestPricePoint = prevBarLowPrice;
            }
      }
   }
   
   if(!endOfRange) {
      if(RangeTimeEnd == time) {
         rangeStarted = false;
         endOfRange = true;
         //reset lowest and highest price points;
         int firstBarIndex = iBarShift(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart), true);
         if(firstBarIndex == 0) {
            highestPricePoint = iHigh(_Symbol, PERIOD_CURRENT, firstBarIndex);
            lowestPricePoint = iLow(_Symbol, PERIOD_CURRENT, firstBarIndex);
         }
         //reset bars;
         barsSinceStartOfRange = 0;
      }
   } else {
      int easTrades = 0;
      int easOrders = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         ulong positionTicket = PositionGetTicket(i);
         long positionMagic = PositionGetInteger(POSITION_MAGIC);
         if(positionMagic == Magic) {
            easTrades++;
            if(time == endTradeTime) {
               trade.PositionClose(positionTicket);
               allowTrades = false;
            }
         }
      }
      
      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         ulong orderTicket = OrderGetTicket(i);
         long orderMagic = OrderGetInteger(ORDER_MAGIC);
         if(orderMagic == Magic) {
            if(time == endTradeTime) {
               trade.OrderDelete(orderTicket);
               allowTrades = false;
               easOrders = 0;
            }
            easOrders++;
         }
         
      }
      
      if(allowTrades) {
         if(easOrders < 1) {
         trade.BuyStop(1, highestPricePoint, _Symbol, lowestPricePoint);
         trade.SellStop(1, lowestPricePoint, _Symbol, highestPricePoint);
         }
      }
   }
  }
//+------------------------------------------------------------------+
