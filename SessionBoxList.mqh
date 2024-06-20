//+------------------------------------------------------------------+
//|                                               SessionBoxList.mqh |
//|                                           Diamoind Systems Corp. |
//|                                   https://github.com/mql-systems |
//+------------------------------------------------------------------+
#property copyright "Diamoind Systems Corp."
#property link "https://github.com/mql-systems"
#property version "1.00"

#define OBJPROP_RECTANGLE_HIGH_POINT 0
#define OBJPROP_RECTANGLE_LOW_POINT  1

enum ENUM_SESSION_BOX_HIGH_LOW
{
   SESSION_BOX_HIGH_LOW_DAY,
   SESSION_BOX_HIGH_LOW_SESSION,
   SESSION_BOX_HIGH_LOW_CUSTOM,
};

struct SessionBox
{
   datetime                   date;
   int                        startInSeconds;
   int                        durationInSeconds;
   ENUM_SESSION_BOX_HIGH_LOW  highLowType;
   double                     high;
   double                     low;
   color                      clr;
   bool                       isCustomHighLow;
   void                       SessionBox::SessionBox(void): isCustomHighLow(false), high(0.0), low(0.0) {}
};

//+------------------------------------------------------------------+
//| Session Box list                                                 |
//+------------------------------------------------------------------+
class CSessionBoxList
{
private:
   long              m_chartID;
   int               m_subWindow;
   string            m_sessionName;
   color             m_boxColor;
   int               m_sessionStartInSeconds;
   int               m_sessionDurationInSeconds;
   ENUM_SESSION_BOX_HIGH_LOW m_sessionHighLow;
   int               m_minDaysInHistory;
   int               m_sessionHighCustomPoints;
   int               m_sessionLowCustomPoints;
   string            m_symbol;
   ENUM_TIMEFRAMES   m_period;
   double            m_point;
   int               m_digits;
   //---
   SessionBox        m_sessionBoxList[];
   int               m_sessionBoxTotal;
   bool              m_isInit;
   string            m_lastError;
   datetime          m_newSessionDay;
   datetime          m_newSessionStartTime;
   datetime          m_newSessionEndTime;
   datetime          m_newSessionCalcBarTime;
   int               m_addNewSessionsErrorCnt;

protected:
   void              ResetLastError(void) { m_lastError = ""; };
   void              SetLastError(string errorMsg) { m_lastError = errorMsg; };
   bool              CompareDouble(double d1, double d2) { return (NormalizeDouble(d1 - d2, 8) == 0); }
   //---
   bool              ProcessingNewSession(void);
   bool              AddNewSessions(void);
   //---
   bool              HighLowDay(const datetime sessionDay, double &high, double &low);
   bool              HighLowSession(const datetime sessionDay, double &high, double &low);
   bool              HighLowCustom(const datetime sessionDay, double &high, double &low);

public:
                     CSessionBoxList(void);
                    ~CSessionBoxList(void);
   //--- Events
   bool              Init(
                        string sessionName,
                        const int sessionStartInMinutes,
                        const int sessionDurationInMinutes,
                        const ENUM_SESSION_BOX_HIGH_LOW sessionHighLow = SESSION_BOX_HIGH_LOW_DAY,
                        const color boxColor = clrOrange,
                        const int minDaysInHistory = 22,
                        const long chartID = 0,
                        const int subWindow = 0);
   bool              Tick(void);
   //---
   string            GetLastError(void) { return m_lastError; };
   //---
   int               Total(void) { return m_sessionBoxTotal; };
   bool              Get(const int pos, SessionBox &sessionBox);
   int               Search(const datetime sessionDay);
   int               Search(const datetime sessionDay, SessionBox &sessionBox);
   bool              Delete(const int pos);
   bool              Delete(const datetime sessionDay);
   void              Clear(void);
   //---
   bool              Update(const int pos, double high = 0.0, double low = 0.0, color clr = NULL);
   bool              Update(const datetime sessionDay, double high = 0.0, double low = 0.0, color clr = NULL);
   bool              UpdateHighLowType(const int pos, const ENUM_SESSION_BOX_HIGH_LOW highLowType);
   bool              UpdateHighLowType(const datetime sessionDay, const ENUM_SESSION_BOX_HIGH_LOW highLowType);
   //---
   int               HighCustomPoints(void) { return m_sessionHighCustomPoints; };
   void              HighCustomPoints(const int points, bool forceAll = false);
   int               LowCustomPoints(void) { return m_sessionLowCustomPoints; };
   void              LowCustomPoints(const int points, bool forceAll = false);
   //---
   bool              DrawSessionBoxObject(const int pos);
   bool              DrawSessionBoxObject(const SessionBox &sessionBox);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSessionBoxList::CSessionBoxList(void) : m_chartID(NULL),
                                         m_subWindow(NULL),
                                         m_symbol(NULL),
                                         m_period(NULL),
                                         m_point(NULL),
                                         m_digits(NULL),
                                         m_sessionName(NULL),
                                         m_boxColor(clrOrange),
                                         m_sessionStartInSeconds(0),
                                         m_sessionDurationInSeconds(0),
                                         m_sessionHighLow(SESSION_BOX_HIGH_LOW_DAY),
                                         m_minDaysInHistory(22),
                                         m_sessionHighCustomPoints(0),
                                         m_sessionLowCustomPoints(0),
                                         m_sessionBoxTotal(0),
                                         m_isInit(false),
                                         m_lastError(""),
                                         m_newSessionDay(0),
                                         m_newSessionStartTime(0),
                                         m_newSessionEndTime(0),
                                         m_newSessionCalcBarTime(0),
                                         m_addNewSessionsErrorCnt(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSessionBoxList::~CSessionBoxList(void)
{
   Clear();
}

//+------------------------------------------------------------------+
//| For OnInit event                                                 |
//+------------------------------------------------------------------+
bool CSessionBoxList::Init(
   string sessionName,
   const int sessionStartInMinutes,
   const int sessionDurationInMinutes,
   const ENUM_SESSION_BOX_HIGH_LOW sessionHighLow,
   const color boxColor,
   const int minDaysInHistory,
   const long chartID,
   const int subWindow)
{
   //--- check sessionName argument
   StringTrimLeft(sessionName);
   StringTrimRight(sessionName);
   if (StringLen(sessionName) == 0)
   {
      SetLastError("Invalid \"sessionName\" argument.");
      return false;
   }

   //--- check sessionStartInMinutes argument
   if (sessionStartInMinutes < 0 || sessionStartInMinutes > 1439)
   {
      SetLastError("Invalid \"sessionStartInMinutes\" argument.");
      return false;
   }

   //--- check sessionDurationInSeconds argument
   if (sessionDurationInMinutes <= 0 || sessionDurationInMinutes > 1440)
   {
      SetLastError("Invalid \"sessionDurationInSeconds\" argument.");
      return false;
   }

   //--- check minDaysInHistory argument
   if (minDaysInHistory > (365*2) || minDaysInHistory < 0)
   {
      SetLastError("Max can only be calculated for the last 2 years, min 0 day");
      return false;
   }
   
   //---
   m_chartID = (chartID > 0) ? chartID : ChartID();

   m_symbol = ChartSymbol(m_chartID);
   if (StringLen(m_symbol) == 0)
   {
      SetLastError("Incorrect ChartID.");
      return false;
   }

   m_period = ChartPeriod(m_chartID);
   if (m_period >= PERIOD_D1)
   {
      SetLastError("It is impossible to draw sessions on daily charts or more.");
      return false;
   }

   //---
   m_sessionName = "SessionBox_" + sessionName;
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_minDaysInHistory = minDaysInHistory;
   m_sessionStartInSeconds = sessionStartInMinutes * 60;
   m_sessionDurationInSeconds = sessionDurationInMinutes * 60;
   m_boxColor = boxColor;
   m_sessionHighLow = sessionHighLow;
   m_subWindow = (m_subWindow > 0) ? subWindow : 0;

   //--- success
   m_isInit = true;
   ResetLastError();

   return true;
}

//+------------------------------------------------------------------+
//| For OnTick event                                                 |
//+------------------------------------------------------------------+
bool CSessionBoxList::Tick(void)
{
   if (! m_isInit)
   {
      SetLastError("First, set the necessary parameters by calling the Init() method.");
      return false;
   }
   
   //--- new session day
   if (m_newSessionDay != iTime(m_symbol, PERIOD_D1, 0) && ! ProcessingNewSession())
      return false;
   
   //--- current session day
   if (m_newSessionStartTime == 0)
      return true;

   SessionBox sessionBox = m_sessionBoxList[m_sessionBoxTotal - 1];
   if (sessionBox.isCustomHighLow)
      return true;
   
   double high, low;
   if (sessionBox.highLowType == SESSION_BOX_HIGH_LOW_DAY || m_newSessionStartTime > TimeCurrent())
   {
      high = iHigh(m_symbol, PERIOD_D1, 0);
      low = iLow(m_symbol, PERIOD_D1, 0);
   }
   else
   {
      if (m_newSessionEndTime < TimeCurrent())
      {
         m_newSessionStartTime = m_newSessionEndTime = m_newSessionCalcBarTime = 0;
         return true;
      }
      
      high = low = 0.0;
      if (m_newSessionCalcBarTime != iTime(m_symbol, PERIOD_M1, 0))
      {
         MqlRates ratesArr[];
         int ratesCnt = CopyRates(m_symbol, PERIOD_M1, m_newSessionStartTime, iTime(m_symbol, PERIOD_M1, 0), ratesArr);
         for (int i = 0; i < ratesCnt; i++)
         {
            if (ratesArr[i].high > high)
               high = ratesArr[i].high;
            if (low == 0.0 || ratesArr[i].low < low)
               low = ratesArr[i].low;
         }
      }
      else
      {
         high = iHigh(m_symbol, PERIOD_M1, 0);
         low = iLow(m_symbol, PERIOD_M1, 0);
      }

      if (sessionBox.highLowType == SESSION_BOX_HIGH_LOW_CUSTOM)
      {
         if (high > 0.0)
            high = NormalizeDouble(high + (m_sessionHighCustomPoints * m_point), m_digits);
         if (low > 0.0)
            low = NormalizeDouble(low - (m_sessionLowCustomPoints * m_point), m_digits);
      }
   }

   if (sessionBox.high < high || (low > 0.0 && sessionBox.low > low))
   {
      if (high > 0.0)
         sessionBox.high = high;
      if (low > 0.0)
         sessionBox.low = low;
      DrawSessionBoxObject(sessionBox);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Processing a new session                                         |
//+------------------------------------------------------------------+
bool CSessionBoxList::ProcessingNewSession(void)
{
   bool isAddSessions = AddNewSessions();
   if (isAddSessions || ++m_addNewSessionsErrorCnt > 2)
   {
      m_newSessionDay = iTime(m_symbol, PERIOD_D1, 0);
      m_addNewSessionsErrorCnt = 0;
      if (! isAddSessions)
         return false;
   }
   else
      return false;

   SessionBox sessionBox = m_sessionBoxList[m_sessionBoxTotal - 1];
   if (sessionBox.date == 0)
   {
      SetLastError("No date has been set for the session.");
      return false;
   }

   m_newSessionStartTime = sessionBox.date + sessionBox.startInSeconds;
   m_newSessionEndTime = m_newSessionStartTime + sessionBox.durationInSeconds;

   return true;
}

//+------------------------------------------------------------------+
//| Add new sessions                                                 |
//+------------------------------------------------------------------+
bool CSessionBoxList::AddNewSessions(void)
{
   if (m_sessionBoxTotal > 0 && m_sessionBoxList[m_sessionBoxTotal - 1].date == iTime(m_symbol, PERIOD_D1, 0))
      return true;
   
   ::ResetLastError();

   int barIndex;
   if (m_sessionBoxTotal == 0)
      barIndex = m_minDaysInHistory - 1;
   else
   {
      datetime lastDate = m_sessionBoxList[m_sessionBoxTotal - 1].date;
      barIndex = iBarShift(m_symbol, PERIOD_D1, lastDate, false);
      if (barIndex < 0)
      {
         SetLastError("iBarShift error! Error code: " + IntegerToString(::GetLastError()));
         return false;
      }
      
      datetime checkDate;
      while (barIndex >= 0)
      {
         checkDate = iTime(m_symbol, PERIOD_D1, barIndex);
         if (lastDate < checkDate)
            break;
         barIndex--;
         if (lastDate == checkDate)
            break;
      }
   }

   if (ArrayResize(m_sessionBoxList, m_sessionBoxTotal + barIndex + 1) < 0)
   {
      m_sessionBoxTotal = ArraySize(m_sessionBoxList);

      SetLastError("ArrayResize error! Error code: " + IntegerToString(::GetLastError()));
      return false;
   }

   bool isHighLow;
   for (int i = barIndex; i >= 0; i--)
   {
      SessionBox sessionBox;
      sessionBox.date = iTime(m_symbol, PERIOD_D1, i);
      sessionBox.startInSeconds = m_sessionStartInSeconds;
      sessionBox.durationInSeconds = m_sessionDurationInSeconds;
      sessionBox.highLowType = m_sessionHighLow;
      sessionBox.clr = m_boxColor;
      sessionBox.isCustomHighLow = false;

      if (sessionBox.date > 0)
      {
         switch (m_sessionHighLow)
         {
            case SESSION_BOX_HIGH_LOW_DAY:
               isHighLow = HighLowDay(sessionBox.date, sessionBox.high, sessionBox.low);
               break;
            case SESSION_BOX_HIGH_LOW_SESSION:
               isHighLow = HighLowSession(sessionBox.date, sessionBox.high, sessionBox.low);
               break;
            case SESSION_BOX_HIGH_LOW_CUSTOM:
               isHighLow = HighLowCustom(sessionBox.date, sessionBox.high, sessionBox.low);
               break;
            default: isHighLow = false;
         }

         if (isHighLow)
            DrawSessionBoxObject(sessionBox);
      }

      m_sessionBoxList[m_sessionBoxTotal++] = sessionBox;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Сalculate the High & Low of the day                              |
//+------------------------------------------------------------------+
bool CSessionBoxList::HighLowDay(const datetime sessionDay, double &high, double &low)
{
   int barIndex = iBarShift(m_symbol, PERIOD_D1, sessionDay, true);
   if (barIndex < 0)
   {
      SetLastError("iBarShift error! Error code: " + IntegerToString(::GetLastError()));
      return false;
   }
   
   double dayHigh = iHigh(m_symbol, PERIOD_D1, barIndex);
   double dayLow = iLow(m_symbol, PERIOD_D1, barIndex);

   if (dayHigh == 0.0 || dayLow == 0.0)
   {
      SetLastError("Error in calculating the High & Low of the day.");
      return false;
   }
   
   high = dayHigh;
   low = dayLow;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate High & Low Sessions                                    |
//+------------------------------------------------------------------+
bool CSessionBoxList::HighLowSession(const datetime sessionDay, double &high, double &low)
{
   MqlRates ratesArr[];
   datetime sessionStart = sessionDay + m_sessionStartInSeconds;

   //--- future session
   if (TimeCurrent() <= sessionStart)
   {
      high = 0.0;
      low = 0.0;
      return true;
   }

   //--- past and current session
   int ratesCnt = CopyRates(m_symbol, PERIOD_M1, sessionStart, (sessionStart + m_sessionDurationInSeconds) - 1, ratesArr);
   if (ratesCnt < 1)
   {
      SetLastError("CopyRates error! Error code: " + IntegerToString(::GetLastError()));
      return false;
   }
   
   double priceHigh = 0.0;
   double priceLow = INT_MAX;

   for (int i = 0; i < ratesCnt; i++)
   {
      if (ratesArr[i].high > priceHigh)
         priceHigh = ratesArr[i].high;
      if (ratesArr[i].low < priceLow)
         priceLow = ratesArr[i].low;
   }

   if (priceHigh == 0.0 || priceLow > priceHigh)
   {
      SetLastError("Error in calculating the High & Low session.");
      return false;
   }
   
   high = priceHigh;
   low = priceLow;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate High & Low Custom                                      |
//+------------------------------------------------------------------+
bool CSessionBoxList::HighLowCustom(const datetime sessionDay, double &high, double &low)
{
   if (HighLowSession(sessionDay, high, low))
   {
      high = NormalizeDouble(high + (m_sessionHighCustomPoints * m_point), m_digits);
      low = NormalizeDouble(low - (m_sessionLowCustomPoints * m_point), m_digits);
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Get a SessionBox by index                                        |
//+------------------------------------------------------------------+
bool CSessionBoxList::Get(const int pos, SessionBox &sessionBox)
{
   if (pos < 0 || pos >= m_sessionBoxTotal)
   {
      SetLastError("Session not found");
      return false;
   }

   sessionBox = m_sessionBoxList[m_sessionBoxTotal - pos - 1];

   return true;
}

//+------------------------------------------------------------------+
//| Get the SessionBox by time of day. The index of the found        |
//| session is returned, or -1 if nothing is found.                  |
//+------------------------------------------------------------------+
int CSessionBoxList::Search(const datetime sessionDay)
{
   if (sessionDay < 86400)
      return (-1);
   
   datetime sessionDate = sessionDay - (sessionDay % 86400);

   int m, left = 0, right = m_sessionBoxTotal - 1;
   while (left <= right)
   {
      m = left + (right - left) / 2;
      if (m_sessionBoxList[m].date == sessionDate)
         return m;
      if (m_sessionBoxList[m].date < sessionDate)
         left = m + 1;
      if (m_sessionBoxList[m].date > sessionDate)
         right = m - 1;
   }

   return (-1);
}

//+------------------------------------------------------------------+
//| Get the SessionBox by time of day. The index of the found        |
//| session is returned, or -1 if nothing is found.                  |
//| Additionally gets the SessionBox structure.                      |
//+------------------------------------------------------------------+
int CSessionBoxList::Search(const datetime sessionDay, SessionBox &sessionBox)
{
   int pos = Search(sessionDay);
   if (pos >= 0)
      sessionBox = m_sessionBoxList[pos];
   
   return pos;
}

//+------------------------------------------------------------------+
//| Delete a session in the specified position                       |
//+------------------------------------------------------------------+
bool CSessionBoxList::Delete(const int pos)
{
   if (pos < 0 || pos >= m_sessionBoxTotal)
      return true;
   
   datetime date = m_sessionBoxList[pos].date;
   if (! ArrayRemove(m_sessionBoxList, pos, 1))
   {
      SetLastError("Session not found");
      return false;
   }

   ObjectDelete(m_chartID, m_sessionName + TimeToString(date));
   m_sessionBoxTotal = ArraySize(m_sessionBoxList);

   return true;
}

//+------------------------------------------------------------------+
//| Delete a session on the specified date                           |
//+------------------------------------------------------------------+
bool CSessionBoxList::Delete(const datetime sessionDay)
{
   return Delete(Search(sessionDay));
}

//+------------------------------------------------------------------+
//| Delete all sessions                                              |
//+------------------------------------------------------------------+
void CSessionBoxList::Clear(void)
{
   ArrayFree(m_sessionBoxList);
   m_sessionBoxTotal = 0;
   ObjectsDeleteAll(m_chartID, m_sessionName);
}

//+------------------------------------------------------------------+
//| Update a session in the specified position                       |
//+------------------------------------------------------------------+
bool CSessionBoxList::Update(const int pos, double high, double low, color clr)
{
   if (pos < 0 || pos >= m_sessionBoxTotal)
   {
      SetLastError("Session not found");
      return false;
   }

   double pH = NormalizeDouble(high, m_digits);
   double pL = NormalizeDouble(low, m_digits);
   string sessionName = m_sessionName + TimeToString(m_sessionBoxList[pos].date);

   if (clr != NULL && m_sessionBoxList[pos].clr != clr)
      m_sessionBoxList[pos].clr = clr;
   
   if (high > 0.0 && ! CompareDouble(m_sessionBoxList[pos].high, pH))
   {
      m_sessionBoxList[pos].high = pH;
      m_sessionBoxList[pos].highLowType = SESSION_BOX_HIGH_LOW_CUSTOM;
      m_sessionBoxList[pos].isCustomHighLow = true;
      ObjectSetDouble(m_chartID, sessionName, OBJPROP_PRICE, OBJPROP_RECTANGLE_HIGH_POINT, pH);
   }

   if (low > 0.0 && ! CompareDouble(m_sessionBoxList[pos].low, pL))
   {
      m_sessionBoxList[pos].low = pL;
      m_sessionBoxList[pos].highLowType = SESSION_BOX_HIGH_LOW_CUSTOM;
      m_sessionBoxList[pos].isCustomHighLow = true;
      ObjectSetDouble(m_chartID, sessionName, OBJPROP_PRICE, OBJPROP_RECTANGLE_LOW_POINT, pL);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Update a session in the specified date                           |
//+------------------------------------------------------------------+
bool CSessionBoxList::Update(const datetime sessionDay, double high, double low, color clr)
{
   return Update(Search(sessionDay), high, low, clr);
}

//+------------------------------------------------------------------+
//| Update a session in the specified date                           |
//+------------------------------------------------------------------+
bool CSessionBoxList::UpdateHighLowType(const int pos, const ENUM_SESSION_BOX_HIGH_LOW highLowType)
{
   if (pos < 0 || pos >= m_sessionBoxTotal)
   {
      SetLastError("Session not found");
      return false;
   }

   if (m_sessionBoxList[pos].highLowType == highLowType)
      return true;
   
   bool res;
   switch (highLowType)
   {
      case SESSION_BOX_HIGH_LOW_DAY:
         res = HighLowDay(m_sessionBoxList[pos].date, m_sessionBoxList[pos].high, m_sessionBoxList[pos].low);
         break;
      case SESSION_BOX_HIGH_LOW_SESSION:
         res = HighLowSession(m_sessionBoxList[pos].date, m_sessionBoxList[pos].high, m_sessionBoxList[pos].low);
         break;
      case SESSION_BOX_HIGH_LOW_CUSTOM:
         res = HighLowCustom(m_sessionBoxList[pos].date, m_sessionBoxList[pos].high, m_sessionBoxList[pos].low);
         break;
      default: return true;
   }

   if (res)
   {
      string sessionName = m_sessionName + TimeToString(m_sessionBoxList[pos].date);
      ObjectSetDouble(m_chartID, sessionName, OBJPROP_PRICE, OBJPROP_RECTANGLE_HIGH_POINT, m_sessionBoxList[pos].high);
      ObjectSetDouble(m_chartID, sessionName, OBJPROP_PRICE, OBJPROP_RECTANGLE_LOW_POINT, m_sessionBoxList[pos].low);
   }

   return res;
}

//+------------------------------------------------------------------+
//| Update a session in the specified date                           |
//+------------------------------------------------------------------+
bool CSessionBoxList::UpdateHighLowType(const datetime sessionDay, const ENUM_SESSION_BOX_HIGH_LOW highLowType)
{
   return Update(Search(sessionDay), highLowType);
}

//+------------------------------------------------------------------+
//| Add high points for the custom session                           |
//+------------------------------------------------------------------+
void CSessionBoxList::HighCustomPoints(const int points, bool forceAll)
{
   if (points < 0)
      return;
   
   double emptyLow;
   double pDiff = points - m_sessionHighCustomPoints;

   m_sessionHighCustomPoints = points;

   for (int i = ArraySize(m_sessionBoxList) - 1; i >= 0; i--)
   {
      if (m_sessionBoxList[i].highLowType != SESSION_BOX_HIGH_LOW_CUSTOM)
         continue;
      if (m_sessionBoxList[i].high == 0.0 || (m_sessionBoxList[i].isCustomHighLow && forceAll))
      {
         if (! HighLowCustom(m_sessionBoxList[i].date, m_sessionBoxList[i].high, emptyLow))
            continue;
      }
      else if (pDiff != 0 && ! m_sessionBoxList[i].isCustomHighLow)
         m_sessionBoxList[i].high = NormalizeDouble(m_sessionBoxList[i].high + (pDiff * m_point), m_digits);
      else
         continue;
      
      ObjectSetDouble(m_chartID, m_sessionName + TimeToString(m_sessionBoxList[i].date), OBJPROP_PRICE, OBJPROP_RECTANGLE_HIGH_POINT, m_sessionBoxList[i].high);
   }
}

//+------------------------------------------------------------------+
//| Add low points for the custom session                            |
//+------------------------------------------------------------------+
void CSessionBoxList::LowCustomPoints(const int points, bool forceAll)
{
   if (points < 0)
      return;
   
   double emptyHigh;
   double pDiff = points - m_sessionLowCustomPoints;

   m_sessionLowCustomPoints = points;

   for (int i = ArraySize(m_sessionBoxList) - 1; i >= 0; i--)
   {
      if (m_sessionBoxList[i].highLowType != SESSION_BOX_HIGH_LOW_CUSTOM)
         continue;
      if (m_sessionBoxList[i].low == 0.0 || (m_sessionBoxList[i].isCustomHighLow && forceAll))
      {
         if (! HighLowCustom(m_sessionBoxList[i].date, emptyHigh, m_sessionBoxList[i].low))
            continue;
      }
      else if (pDiff != 0 && ! m_sessionBoxList[i].isCustomHighLow)
         m_sessionBoxList[i].low = NormalizeDouble(m_sessionBoxList[i].low - (pDiff * m_point), m_digits);
      else
         continue;
      
      ObjectSetDouble(m_chartID, m_sessionName + TimeToString(m_sessionBoxList[i].date), OBJPROP_PRICE, OBJPROP_RECTANGLE_LOW_POINT, m_sessionBoxList[i].low);
   }
}

//+------------------------------------------------------------------+
//| Draw a SessionBox object                                         |
//+------------------------------------------------------------------+
bool CSessionBoxList::DrawSessionBoxObject(const int pos)
{
   if (pos < 0 || pos >= m_sessionBoxTotal)
   {
      SetLastError("Session not found");
      return false;
   }

   return DrawSessionBoxObject(m_sessionBoxList[pos]);
}

//+------------------------------------------------------------------+
//| Draw a SessionBox object                                         |
//+------------------------------------------------------------------+
bool CSessionBoxList::DrawSessionBoxObject(const SessionBox &sessionBox)
{
   string sessionBoxName = m_sessionName + TimeToString(sessionBox.date);

   if (ObjectFind(m_chartID, sessionBoxName) < 0)
   {
      ::ResetLastError();

      datetime sessionStart = sessionBox.date + sessionBox.startInSeconds;

      if (! ObjectCreate(m_chartID, sessionBoxName, OBJ_RECTANGLE, m_subWindow, sessionStart, sessionBox.high, sessionStart + sessionBox.durationInSeconds - 1, sessionBox.low))
      {
         SetLastError("Failed to create a rectangle! Error code: " + IntegerToString(::GetLastError()));
         return false;
      }
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_COLOR, sessionBox.clr);
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_FILL, true);
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_BACK, true);
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_SELECTED, false);
      ObjectSetInteger(m_chartID, sessionBoxName, OBJPROP_HIDDEN, true);
   }
   else
   {
      if (! CompareDouble(sessionBox.high, ObjectGetDouble(m_chartID, sessionBoxName, OBJPROP_PRICE, OBJPROP_RECTANGLE_HIGH_POINT)))
         ObjectSetDouble(m_chartID, sessionBoxName, OBJPROP_PRICE, OBJPROP_RECTANGLE_HIGH_POINT, sessionBox.high);
      if (! CompareDouble(sessionBox.low, ObjectGetDouble(m_chartID, sessionBoxName, OBJPROP_PRICE, OBJPROP_RECTANGLE_LOW_POINT)))
         ObjectSetDouble(m_chartID, sessionBoxName, OBJPROP_PRICE, OBJPROP_RECTANGLE_LOW_POINT, sessionBox.low);
   }

   ChartRedraw(m_chartID);

   return true;
}

//+------------------------------------------------------------------+