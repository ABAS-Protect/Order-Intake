/*
    Author: Niklas Dougherty <nd@abas.se>
    Date: 2026-08-27
    Description: Place weekly order intake in Reports on Sales Orders.
*/

pageextension 50102 "Order Intake Nav Ext" extends "Sales Order List"
{
    actions
    {
        addlast(reporting)
        {
            action("Order Intake Sales Card")
            {
                ApplicationArea = All;
                Caption = 'ABAS Order Intake';
                Image = "Report";
                ToolTip = 'Open the rolling 12-month order intake.';

                trigger OnAction()
                begin
                    Page.Run(Page::"ABAS Order Intake");
                end;
            }
        }
    }
}