/*
    Author: Niklas Dougherty <nd@abas.se>
    Date: 2026-08-27
    Description: List weekly order intake YoY, with optional sources.
*/

page 50102 "ABAS Order Intake"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = Integer;
    SourceTableTemporary = true;
    Caption = 'ABAS Order Intake';
    Editable = true;
    DeleteAllowed = false;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Filters & Inclusions';

                field(IncCrMemo; IncludeCreditMemos)
                {
                    ApplicationArea = All;
                    Caption = 'Include Posted Credit Memos';

                    trigger OnValidate()
                    begin
                        RefreshPageData();
                    end;
                }
                field(IncServOrd; IncludeServiceOrders)
                {
                    ApplicationArea = All;
                    Caption = 'Include Service Orders';

                    trigger OnValidate()
                    begin
                        RefreshPageData();
                    end;
                }
                // field(IncServInv; IncludeServiceInvoices)
                // {
                //     ApplicationArea = All;
                //     Caption = 'Include Posted Service Invoices';

                //     trigger OnValidate()
                //     begin
                //         RefreshPageData();
                //     end;
                // }
                field(IncSalesOrd; IncludeSalesOrders)
                {
                    ApplicationArea = All;
                    Caption = 'Include Sales Orders';

                    trigger OnValidate()
                    begin
                        RefreshPageData();
                    end;
                }
                field(IncPostedInvoices; IncludePostedInvoices)
                {
                    ApplicationArea = All;
                    Caption = 'Include Posted Invoices';

                    trigger OnValidate()
                    begin
                        RefreshPageData();
                    end;
                }
                field(IncRetOrd; IncludeReturnOrders)
                {
                    ApplicationArea = All;
                    Caption = 'Include Sales Return Orders';

                    trigger OnValidate()
                    begin
                        RefreshPageData();
                    end;
                }
            }
            repeater(Group)
            {
                Editable = false;
                field("Year"; DisplayYear)
                {
                    ApplicationArea = All;
                    Caption = 'Year';
                }
                field("Month"; MonthText)
                {
                    ApplicationArea = All;
                    Caption = 'Month';
                }
                field("Week"; WeekNumber)
                {
                    ApplicationArea = All;
                    Caption = 'Week';
                }
                field("Amount"; PeriodAmount)
                {
                    ApplicationArea = All;
                    Caption = 'Amount (LCY)';
                }
            }
            grid(TotalsGrid)
            {
                ShowCaption = false;
                GridLayout = Columns;

                group(TotalRowGroup)
                {
                    ShowCaption = false;

                    field(TotalLabel; GrandTotalLbl)
                    {
                        ApplicationArea = All;
                        Editable = false;
                        Style = Strong;
                        ShowCaption = false;
                    }
                    field(TotalAmountField; GrandTotalAmount)
                    {
                        ApplicationArea = All;
                        Editable = false;
                        Style = Strong;
                        DecimalPlaces = 2 : 2;
                        ShowCaption = false;
                    }
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RefreshData)
            {
                ApplicationArea = All;
                Caption = 'Refresh';
                Image = Refresh;
                ToolTip = 'Recalculate order intake for the last 12 months.';

                trigger OnAction()
                begin
                    RefreshPageData();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(RefreshData_Promoted; RefreshData) { }
            }
        }
    }

    var
        DisplayYear: Integer;
        MonthText: Text;
        WeekNumber: Integer;
        PeriodAmount: Decimal;
        MonthsToLookBack: Integer;
        WeeklyTotals: Dictionary of [Integer, Decimal];
        GrandTotalAmount: Decimal;
        GrandTotalLbl: Label 'Grand Total Amount:';
        IncludeCreditMemos: Boolean;
        IncludeServiceOrders: Boolean;
        // IncludeServiceInvoices: Boolean;
        IncludeSalesOrders: Boolean;
        IncludePostedInvoices: Boolean;
        IncludeReturnOrders: Boolean;

    trigger OnOpenPage()
    begin
        IncludeSalesOrders := true;
        IncludePostedInvoices := true;
        IncludeReturnOrders := true;
        IncludeCreditMemos := true;
        IncludeServiceOrders := true;
        // IncludeServiceInvoices := true;
        PopulateBuffer();
    end;

    trigger OnAfterGetRecord()
    begin
        DecodeKeyAndValues();
    end;

    local procedure RefreshPageData()
    begin
        Rec.Reset();
        Rec.DeleteAll();
        Clear(WeeklyTotals);
        PopulateBuffer();
        CurrPage.Update(false);
    end;

    local procedure PopulateBuffer()
    var
        DictKey: Integer;
        TempAmt: Decimal;
        StartDate: Date;
        EndDate: Date;
        YrFromKey: Integer;
        WkFromKey: Integer;
        WkMonday: Date;
    begin
        EndDate := WorkDate();
        StartDate := EndDate - 365;

        if IncludeSalesOrders then
            CollectSalesOrders(StartDate, EndDate);

        if IncludePostedInvoices then
            CollectPostedInvoices(StartDate, EndDate);

        if IncludeReturnOrders then
            CollectReturnOrders(StartDate, EndDate);

        if IncludeCreditMemos then
            CollectPostedCrMemos(StartDate, EndDate);

        if IncludeServiceOrders then
            CollectServiceOrders(StartDate, EndDate);

        // if IncludeServiceInvoices then
        //     CollectPostedServiceInvoices(StartDate, EndDate);

        GrandTotalAmount := 0;

        foreach DictKey in WeeklyTotals.Keys() do begin
            YrFromKey := DictKey div 100;
            WkFromKey := DictKey mod 100;
            WkMonday := DWY2Date(1, WkFromKey, YrFromKey);

            if (WkMonday >= StartDate) and (WkMonday <= EndDate) then begin
                Rec.Number := DictKey;
                Rec.Insert();

                WeeklyTotals.Get(DictKey, TempAmt);
                GrandTotalAmount += TempAmt;
            end;
        end;

        Rec.Reset();
        Rec.SetCurrentKey(Number);
        Rec.Ascending(false);
        if Rec.FindSet() then;
    end;

    local procedure CollectSalesOrders(StartDate: Date; EndDate: Date)
    var
        H: Record "Sales Header";
        L: Record "Sales Line";
        LcyAmt: Decimal;
    begin
        H.SetRange("Document Type", H."Document Type"::Order);
        H.SetRange("Order Date", StartDate, EndDate);
        if H.FindSet() then
            repeat
                L.SetRange("Document Type", H."Document Type");
                L.SetRange("Document No.", H."No.");
                if L.FindSet() then
                    repeat
                        if H."Currency Factor" <> 0 then
                            LcyAmt := L."Line Amount" / H."Currency Factor"
                        else
                            LcyAmt := L."Line Amount";

                        AddToDict(H."Order Date", LcyAmt);
                    until L.Next() = 0;
            until H.Next() = 0;
    end;

    local procedure CollectPostedInvoices(StartDate: Date; EndDate: Date)
    var
        H: Record "Sales Invoice Header";
        L: Record "Sales Invoice Line";
        LcyAmt: Decimal;
    begin
        H.SetRange("Order Date", StartDate, EndDate);
        if H.FindSet() then
            repeat
                L.SetRange("Document No.", H."No.");
                if L.FindSet() then
                    repeat
                        if H."Currency Factor" <> 0 then
                            LcyAmt := L."Line Amount" / H."Currency Factor"
                        else
                            LcyAmt := L."Line Amount";

                        AddToDict(H."Order Date", LcyAmt);
                    until L.Next() = 0;
            until H.Next() = 0;
    end;

    local procedure CollectReturnOrders(StartDate: Date; EndDate: Date)
    var
        H: Record "Sales Header";
        L: Record "Sales Line";
        LcyAmt: Decimal;
    begin
        H.SetRange("Document Type", H."Document Type"::"Return Order");
        H.SetRange("Order Date", StartDate, EndDate);
        if H.FindSet() then
            repeat
                L.SetRange("Document Type", H."Document Type");
                L.SetRange("Document No.", H."No.");
                if L.FindSet() then
                    repeat
                        if H."Currency Factor" <> 0 then
                            LcyAmt := L."Line Amount" / H."Currency Factor"
                        else
                            LcyAmt := L."Line Amount";

                        AddToDict(H."Order Date", -LcyAmt);
                    until L.Next() = 0;
            until H.Next() = 0;
    end;

    local procedure CollectPostedCrMemos(StartDate: Date; EndDate: Date)
    var
        H: Record "Sales Cr.Memo Header";
        L: Record "Sales Cr.Memo Line";
        LcyAmt: Decimal;
    begin
        H.SetRange("Posting Date", StartDate, EndDate);
        if H.FindSet() then
            repeat
                L.SetRange("Document No.", H."No.");
                if L.FindSet() then
                    repeat
                        if H."Currency Factor" <> 0 then
                            LcyAmt := L."Line Amount" / H."Currency Factor"
                        else
                            LcyAmt := L."Line Amount";

                        AddToDict(H."Posting Date", -LcyAmt);
                    until L.Next() = 0;
            until H.Next() = 0;
    end;

    local procedure CollectServiceOrders(StartDate: Date; EndDate: Date)
    var
        H: Record "Service Header";
        L: Record "Service Line";
        LcyAmt: Decimal;
    begin
        H.SetRange("Document Type", H."Document Type"::Order);
        H.SetRange("Order Date", StartDate, EndDate);
        if H.FindSet() then
            repeat
                L.SetRange("Document Type", H."Document Type");
                L.SetRange("Document No.", H."No.");
                if L.FindSet() then
                    repeat
                        if H."Currency Factor" <> 0 then
                            LcyAmt := L."Line Amount" / H."Currency Factor"
                        else
                            LcyAmt := L."Line Amount";

                        AddToDict(H."Order Date", LcyAmt);
                    until L.Next() = 0;
            until H.Next() = 0;
    end;

    // local procedure CollectPostedServiceInvoices(StartDate: Date; EndDate: Date)
    // var
    //     H: Record "Service Invoice Header";
    //     L: Record "Service Invoice Line";
    //     LcyAmt: Decimal;
    // begin
    //     H.SetRange("Posting Date", StartDate, EndDate);
    //     if H.FindSet() then
    //         repeat
    //             L.SetRange("Document No.", H."No.");
    //             if L.FindSet() then
    //                 repeat
    //                     if H."Currency Factor" <> 0 then
    //                         LcyAmt := L."Line Amount" / H."Currency Factor"
    //                     else
    //                         LcyAmt := L."Line Amount";

    //                     AddToDict(H."Posting Date", LcyAmt);
    //                 until L.Next() = 0;
    //         until H.Next() = 0;
    // end;

    local procedure AddToDict(TargetDate: Date; Amt: Decimal)
    var
        Yr: Integer;
        Wk: Integer;
        KeyInt: Integer;
        OldAmt: Decimal;
    begin
        if TargetDate = 0D then exit;

        Yr := Date2DMY(TargetDate, 3);
        Wk := Date2DWY(TargetDate, 2);
        KeyInt := (Yr * 100) + Wk;

        if WeeklyTotals.Get(KeyInt, OldAmt) then
            WeeklyTotals.Set(KeyInt, OldAmt + Amt)
        else
            WeeklyTotals.Add(KeyInt, Amt);
    end;

    local procedure DecodeKeyAndValues()
    var
        Yr: Integer;
        Wk: Integer;
        WkStart: Date;
        MidWeekDate: Date;
    begin
        Yr := Rec.Number div 100;
        Wk := Rec.Number mod 100;
        WkStart := DWY2Date(1, Wk, Yr);
        MidWeekDate := DWY2Date(4, Wk, Yr);

        DisplayYear := Yr;
        WeekNumber := Wk;

        MonthText := Format(MidWeekDate, 0, '<Month Text>');

        if not WeeklyTotals.Get(Rec.Number, PeriodAmount) then
            PeriodAmount := 0;
    end;
}