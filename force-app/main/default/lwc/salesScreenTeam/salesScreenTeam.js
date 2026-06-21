import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import saveOpportunityData from '@salesforce/apex/SalesScreenTeamController.saveOpportunityData';
import createSlackList from '@salesforce/apex/SalesScreenTeamController.createSlackListForOpportunity';

const FIELDS = [
    'Opportunity.OEM_Company_Name__c',
    'Opportunity.Contact_Person_Name__c',
    'Opportunity.Contact_Email__c',
    'Opportunity.Contact_Phone_Number__c',
    'Opportunity.Contact_Person_s_Role_Title__c',
    'Opportunity.OEM_Industry_Segment__c',
    'Opportunity.OEM_Website__c',
    'Opportunity.Product_of_Interest__c',
    'Opportunity.Brief_Description_of_Requirement__c',
    'Opportunity.Power_kW__c',
    'Opportunity.Initial_Order_Quantity__c',
    'Opportunity.Estimated_Annual_Quantity_Potential_Vo__c',
    'Opportunity.Target_Price_Budget__c',
    'Opportunity.Are_Drawings_Preliminary_Specifications__c',
    'Opportunity.Delivery_Type__c',
    'Opportunity.Installation_Country__c',
    'Opportunity.Target_First_Delivery_Date_Project_Tim__c',
    'Opportunity.Currency_for_Quotation__c',
    'Opportunity.LeadSource',
    'Opportunity.Urgency_Level__c',
    'Opportunity.Salesperson_s_Initial_Assessment_Notes__c',
    'Opportunity.Next_Action__c',
    'Opportunity.Next_Action_Date__c'
];

export default class SalesScreenTeam extends LightningElement {
    @api recordId;
    @track currentStep = 1;
    @track opportunityData = {};
    @track productDetails = {};
    @track selectedProducts = [];

    steps = [
        'OEM / Inquirer Details',
        'Requirement Overview (High-Level)',
        'Commercial & Logistical Information',
        'Qualification & Next Steps'
    ];

    productOptions = [
        { label: 'Solar Inverters', value: 'Solar Inverters' },
        { label: 'Battery Systems', value: 'Battery Systems' },
        { label: 'Wind Turbines', value: 'Wind Turbines' },
        { label: 'Energy Storage', value: 'Energy Storage' },
        { label: 'Grid Solutions', value: 'Grid Solutions' }
    ];

    industryOptions = [
        { label: 'Manufacturing', value: 'Manufacturing' },
        { label: 'Technology', value: 'Technology' },
        { label: 'Healthcare', value: 'Healthcare' },
        { label: 'Energy', value: 'Energy' },
        { label: 'Automotive', value: 'Automotive' }
    ];

    deliveryOptions = [
        { label: 'Standard', value: 'Standard' },
        { label: 'Express', value: 'Express' },
        { label: 'Custom', value: 'Custom' }
    ];

    countryOptions = [
        { label: 'United States', value: 'United States' },
        { label: 'Canada', value: 'Canada' },
        { label: 'Mexico', value: 'Mexico' },
        { label: 'Germany', value: 'Germany' },
        { label: 'United Kingdom', value: 'United Kingdom' }
    ];

    currencyOptions = [
        { label: 'USD', value: 'USD' },
        { label: 'EUR', value: 'EUR' },
        { label: 'GBP', value: 'GBP' },
        { label: 'CAD', value: 'CAD' },
        { label: 'JPY', value: 'JPY' }
    ];

    leadSourceOptions = [
        { label: 'Website', value: 'Website' },
        { label: 'Referral', value: 'Referral' },
        { label: 'Trade Show', value: 'Trade Show' },
        { label: 'Cold Call', value: 'Cold Call' },
        { label: 'Partner', value: 'Partner' }
    ];

    urgencyOptions = [
        { label: 'Low', value: 'Low' },
        { label: 'Medium', value: 'Medium' },
        { label: 'High', value: 'High' },
        { label: 'Critical', value: 'Critical' }
    ];

    nextActionOptions = [
        { label: 'Follow-up Call', value: 'Follow-up Call' },
        { label: 'Send Proposal', value: 'Send Proposal' },
        { label: 'Schedule Meeting', value: 'Schedule Meeting' },
        { label: 'Technical Review', value: 'Technical Review' }
    ];

    drawingsOptions = [
        { label: 'Yes', value: 'Yes' },
        { label: 'No', value: 'No' },
        { label: 'Preliminary', value: 'Preliminary' }
    ];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredOpportunity({ error, data }) {
        if (data) {
            this.loadOpportunityData(data);
        } else if (error) {
            console.error('Error loading opportunity:', error);
        }
    }

    loadOpportunityData(data) {
        this.opportunityData = {
            oemCompanyName: data.fields.OEM_Company_Name__c?.value || '',
            contactPersonName: data.fields.Contact_Person_Name__c?.value || '',
            contactEmail: data.fields.Contact_Email__c?.value || '',
            contactPhoneNumber: data.fields.Contact_Phone_Number__c?.value || '',
            contactPersonRole: data.fields.Contact_Person_s_Role_Title__c?.value || '',
            oemIndustrySegment: data.fields.OEM_Industry_Segment__c?.value || '',
            oemWebsite: data.fields.OEM_Website__c?.value || '',
            productOfInterest: data.fields.Product_of_Interest__c?.value?.split(';') || [],
            briefDescription: data.fields.Brief_Description_of_Requirement__c?.value || '',
            powerKw: data.fields.Power_kW__c?.value || '',
            initialOrderQuantity: data.fields.Initial_Order_Quantity__c?.value || '',
            estimatedAnnualQuantity: data.fields.Estimated_Annual_Quantity_Potential_Vo__c?.value || '',
            targetPriceBudget: data.fields.Target_Price_Budget__c?.value || '',
            areDrawingsPreliminary: data.fields.Are_Drawings_Preliminary_Specifications__c?.value || '',
            deliveryType: data.fields.Delivery_Type__c?.value || '',
            installationCountry: data.fields.Installation_Country__c?.value || '',
            targetFirstDeliveryDate: data.fields.Target_First_Delivery_Date_Project_Tim__c?.value || '',
            currencyForQuotation: data.fields.Currency_for_Quotation__c?.value || '',
            leadSource: data.fields.LeadSource?.value || '',
            urgencyLevel: data.fields.Urgency_Level__c?.value || '',
            salespersonAssessmentNotes: data.fields.Salesperson_s_Initial_Assessment_Notes__c?.value || '',
            nextAction: data.fields.Next_Action__c?.value || '',
            nextActionDate: data.fields.Next_Action_Date__c?.value || ''
        };
        this.selectedProducts = this.opportunityData.productOfInterest || [];
        this.initializeProductDetails();
    }

    initializeProductDetails() {
        this.selectedProducts.forEach(product => {
            if (!this.productDetails[product]) {
                this.productDetails[product] = {
                    powerKw: this.opportunityData.powerKw || '',
                    initialOrderQuantity: this.opportunityData.initialOrderQuantity || '',
                    estimatedAnnualQuantity: this.opportunityData.estimatedAnnualQuantity || '',
                    targetPriceBudget: this.opportunityData.targetPriceBudget || '',
                    areDrawingsPreliminary: this.opportunityData.areDrawingsPreliminary || ''
                };
            }
        });
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.opportunityData = { ...this.opportunityData, [field]: value };
    }

    handleProductSelection(event) {
        this.selectedProducts = event.detail.value;
        this.opportunityData = { ...this.opportunityData, productOfInterest: this.selectedProducts };
        
        // Initialize product details for new selections
        const newProductDetails = { ...this.productDetails };
        
        // Add new products
        this.selectedProducts.forEach(product => {
            if (!newProductDetails[product]) {
                newProductDetails[product] = {
                    powerKw: '',
                    initialOrderQuantity: '',
                    estimatedAnnualQuantity: '',
                    targetPriceBudget: '',
                    areDrawingsPreliminary: ''
                };
            }
        });
        
        // Remove unselected products
        Object.keys(newProductDetails).forEach(product => {
            if (!this.selectedProducts.includes(product)) {
                delete newProductDetails[product];
            }
        });
        
        this.productDetails = newProductDetails;
    }

    handleProductDetailChange(event) {
        const field = event.target.dataset.field;
        const product = event.target.dataset.id;
        const value = event.target.value;
        
        if (!this.productDetails[product]) {
            this.productDetails[product] = {};
        }
        
        this.productDetails[product][field] = value;
    }

    handleNext() {
        if (this.currentStep < 4) {
            this.currentStep++;
            this.animateStepTransition();
        }
    }

    handlePrevious() {
        if (this.currentStep > 1) {
            this.currentStep--;
            this.animateStepTransition();
        }
    }

    handleStepClick(event) {
        const clickedStep = parseInt(event.currentTarget.dataset.step, 10) + 1;
        if (clickedStep !== this.currentStep) {
            this.currentStep = clickedStep;
            this.animateStepTransition();
        }
    }

    animateStepTransition() {
        const content = this.template.querySelector('.step-content');
        if (content) {
            content.style.opacity = '0';
            content.style.transform = 'translateY(10px)';
            
            setTimeout(() => {
                content.style.opacity = '1';
                content.style.transform = 'translateY(0)';
            }, 50);
        }
    }

    async handleSave() {
        try {
            const saveButton = this.template.querySelector('.save-button');
            if (saveButton) {
                saveButton.disabled = true;
            }

            await saveOpportunityData({
                opportunityId: this.recordId,
                opportunityData: JSON.stringify(this.opportunityData),
                productDetails: JSON.stringify(this.productDetails)
            });

            this.showToast('Success', 'Opportunity data saved successfully', 'success');

            try {
                await createSlackList({ opportunityId: this.recordId });
                this.showToast('Success', 'Slack list created for this opportunity', 'success');
            } catch (listError) {
                console.warn('Slack list creation skipped:', listError.message);
                this.showToast('Info', 'Note: Slack list not created yet. The channel may not be ready.', 'info');
            }

            this.resetForm();
        } catch (error) {
            console.error('Error saving opportunity:', error);
            this.showToast('Error', 'Failed to save opportunity data: ' + error.message, 'error');
        } finally {
            const saveButton = this.template.querySelector('.save-button');
            if (saveButton) {
                saveButton.disabled = false;
            }
        }
    }

    resetForm() {
        this.currentStep = 1;
        this.opportunityData = {};
        this.productDetails = {};
        this.selectedProducts = [];
        this.animateStepTransition();
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }

    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isStep4() { return this.currentStep === 4; }
    get isLastStep() { return this.currentStep === 4; }
    get isFirstStep() { return this.currentStep === 1; }

    get hasSelectedProducts() {
        return this.selectedProducts && this.selectedProducts.length > 0;
    }

    get productDetailsArray() {
        return Object.entries(this.productDetails).map(([name, details]) => ({
            name,
            details
        }));
    }

    getStepClass(index) {
        const stepNumber = index + 1;
        let baseClass = 'step-item';
        
        if (stepNumber === this.currentStep) {
            return `${baseClass} current-step`;
        } else if (stepNumber < this.currentStep) {
            return `${baseClass} completed-step`;
        } else {
            return `${baseClass} inactive-step`;
        }
    }
}