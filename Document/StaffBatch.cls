/*
 * 社員マスタ移送バッチ
 */
global class StaffBatch implements Database.Batchable<sObject>, Database.Stateful {

	global Datetime stDtTm; 			// 処理開始時間
	global Datetime etDtTm; 			// 処理終了時間

	global Integer	totalDat = 0;		// 処理対象データ数
	global Integer	totalPrs = 0;		// 処理データ数
	global Integer	totalErr = 0;		// エラー件数
    
	global List<StaffWork__c>		            targetStaffWorkList;	    // 社員情報マスタ(Work)　finishで削除するために保持

    global Map<String, DepartmentMaster__c>		departmentMasterMap;		// 所属マスタMap（所属区分CDキー）
    global Map<String, TBC_OCC_KBN__c>          occupationMasterMap;		// 職種区分CDMap
    global Map<String, TBC_POST_KBN__c>         jobTitleMasterMap;          //役職区分CD         
	//global Map<String, Account>			        customerMap;				// 職種区分CDマスタMap（職種区分CDキー）
	//global Map<String, Contact>	                privateStoreCustomerMap;	// 役職区分CDマスタMap（役職区分CDをキー）
    
	global String	msgErr	= '';		// エラーメッセージ
	global Boolean	isErr	= false;
    global Boolean isCallNextBatch = true;  // 後続バッチ呼び出しフラグ
    private static final Date DAY_BEFORE_WEEK = System.today().addDays(-Integer.valueOf(System.Label.BEFORE_WEEK)); // システム日付 - 8

    // コンストラクタ
    global StaffBatch() {

        // 社員情報マスタ(Work)削除用
        targetStaffWorkList = new List<StaffWork__c>();
        
        // 所属マスタMap作成
        departmentMasterMap = new Map<String, DepartmentMaster__c>();
        for (DepartmentMaster__c departmentMaster : [SELECT Id, AffiliationTypeCD__c FROM DepartmentMaster__c]) {
            departmentMasterMap.put(DepartmentMaster.AffiliationTypeCD__c, departmentMaster);	// 所属区分CDをキーにする
        }

        occupationMasterMap = new Map<String, TBC_OCC_KBN__c>();
        for (TBC_OCC_KBN__c occupationMaster : [SELECT Id, occ_kbn_cd__c FROM TBC_OCC_KBN__c]) {
            occupationMasterMap.put(occupationMaster.occ_kbn_cd__c, occupationMaster);
        }

        jobTitleMasterMap = new Map<String, TBC_POST_KBN__c>();
        for (TBC_POST_KBN__c jobTitleMaster : [SELECT Id, post_kbn_cd__c FROM TBC_POST_KBN__c]) {
            jobTitleMasterMap.put(jobTitleMaster.post_kbn_cd__c, jobTitleMaster);
        }
        
        // // 職種区分CDマスタ作成
        // customerMap = new Map<String, Account>();
        // for (Account customer : [SELECT Id FROM Account]) {
        //     customerMap.put(customer.Id, customer);	// 職種区分CDをキーにする
        // }
        
        // // 役職区分CDマスタ作成
        // privateStoreCustomerMap = new Map<String, Contact>();
        // for (Contact privateStoreCustomer : [SELECT Id FROM Contact]) {
        //     privateStoreCustomerMap.put(privateStoreCustomer.Id, privateStoreCustomer);	// 役職区分CDをキーにする
        // }
        
    }

    // 開始メソッド
    global Database.QueryLocator start(Database.BatchableContext bc) {

        System.debug('### Start Batch : StaffBatch ###');
		stDtTm = Datetime.now();

        return Database.getQueryLocator(
            'SELECT Id'
                + ', COMPOSITE_KEY__c'
                + ', DATA_CONNECT_DATE__c'
                + ', SHAIN_NO__c'
                + ', LSHAIN_CD__c'
                + ', SHAIN_NAME_KANJI__c'
                + ', SHAIN_NAME_KANA__c'
                + ', SEX_CD__c'
                + ', BIRTHDAY__c'
                + ', HSKIN_STA_DATE__c'
                + ', SYZK_DHYO_TEN_NO__c'
                + ', SYZK_KBN_CD__c'
                + ', OCC_KBN_CD__c'
                + ', POST_KBN_CD__c'
                + ', NYUSHA_DATE__c'
                + ', TAISHA_DATE__c'
                + ', MOD_DATE__c'
                + ', MOD_TERM__c'
            + ' FROM StaffWork__c' );//API参照名
    }

    // 実行メソッド
    global void execute(Database.BatchableContext bc, List<StaffWork__c> staffWorkList){
		        
		System.debug('### Execute Process : StaffBatch ###');
        
        //・レコード取得条件
	    //連携区分 = 'M01'
	    //連携ステータス = '1'
	    //連携日(数式) >= システム日付 - 8
        List<BatchResult__c> batchResults = [
            SELECT
                DATA_CONNECT_DATE__c, // 連携日
                DATA_CONNECT_DIV__c, // 連携区分
                DATA_CONNECT_STS__c, //連携ステータス
                DATA_CONNECT_DATE_Calc__c // 連携日(数式)
            FROM BatchResult__c
            WHERE
                DATA_CONNECT_DIV__c = :BatchResult.DIV_STAFF
                AND DATA_CONNECT_STS__c = :BatchResult.STS_1
                AND DATA_CONNECT_DATE_Calc__c >= :DAY_BEFORE_WEEK
        ];

        if (!batchResults.isEmpty()) {
            Set<String> batchResultConnectDate = new Set<String>();
            for (BatchResult__c br : batchResults) {
                batchResultConnectDate.add(br.DATA_CONNECT_DATE__c);
            }

            totalDat += staffWorkList.size();
            System.debug('### StaffWork__c : ' + staffWorkList.size());

            try{
                // 既存の社員情報を取得するためのキーを作成
                set<String> targetKey = new set<String>();
                for (StaffWork__c rdw : staffWorkList) {
                    targetKey.add(rdw.SHAIN_NO__c);
                }
                
                // 既存社員情報Map作成
                Map<String, User> userMap = new Map<String, User>();
                for (User rd : [SELECT
                                    Id, EmployeeNO__c, LerianEmployeeCD__c, EmployeeNameKanji__c, EmployeeNameKana__c,
                                    GenderCD__c, Birthday__c, RewardCalculationStartDate__c, AffiliationRepresentativeStoreNO__c,
                                    AffiliationTypeCD__c, OccupationTypeCD__c, JobTitleTypeCD__c, 
                                    HireDate__c, RetirementDate__c,UpdateDateAndTime__c, UpdateTerminal__c
                                FROM User WHERE IsActive = True AND EmployeeNO__c =: targetKey]) {
                    userMap.put(rd.EmployeeNO__c, rd);
                }
                
                // 該当社員情報マスタレコードに各値を設定する
                // 該当社員情報マスタレコードが存在しない場合は新規作成してMapに追加する
                for (StaffWork__c rdw : staffWorkList) {
                    if (batchResultConnectDate.contains(rdw.DATA_CONNECT_DATE__c)) {
                        // キー作成
                        String key = rdw.SHAIN_NO__c;
                        
                        // 修理表明細Mapに該当レコードが存在するか
                        if (userMap.containsKey(key)) {
                            // 存在する場合
                            User rd = userMap.get(key);
                            //1.社員NO（当該項目でUPSERT）
                            rd.EmployeeNO__c	= key;
                            //2.レリアン社員CD
                            rd.LerianEmployeeCD__c				        = rdw.LSHAIN_CD__c;
                            //3.社員名称（漢字）
                            rd.EmployeeNameKanji__c				        = rdw.SHAIN_NAME_KANJI__c;
                            //4.社員名称（ﾌﾘｶﾞﾅ）
                            rd.EmployeeNameKana__c				        = rdw.SHAIN_NAME_KANA__c;
                            //5.性別CD
                            rd.GenderCD__c					            = rdw.SEX_CD__c;
                            //6.生年月日
                            rd.Birthday__c						        = ConvertUtil.ConvertDateStr(rdw.BIRTHDAY__C);
                            //7.褒賞金計算開始日
                            rd.RewardCalculationStartDate__c			= ConvertUtil.ConvertDateStr(rdw.HSKIN_STA_DATE__C);
                            //8.所属代表店舗NO
                            rd.AffiliationRepresentativeStoreNO__c		= rdw.SYZK_DHYO_TEN_NO__c;
                            
                            //9.所属区分CD（所属マスタ.所属区分CDをキーに紐づけ）
                            rd.AffiliationTypeCD__c = rdw.SYZK_KBN_CD__c;
                            //rd.AffiliationTypeCD__c = ConvertUtil.ConvertRefStr(rdw.SYZK_KBN_CD__c, departmentMasterMap);

                            //10.所属区分CD（所属マスタ.所属区分CDをキーに紐づけ）
                            rd.OccupationTypeCD__c = rdw.OCC_KBN_CD__c;
                            //rd.OccupationTypeCD__c = ConvertUtil.ConvertRefStr(rdw.OCC_KBN_CD__c, occupationMasterMap);
                            
                            //11.役職区分CD（役職区分CDマスタ.役職区分CDをキーに紐づけ）
                            rd.JobTitleTypeCD__c = rdw.POST_KBN_CD__c;
                            //rd.JobTitleTypeCD__c = ConvertUtil.ConvertRefStr(rdw.POST_KBN_CD__c, jobTitleMasterMap);

                            //12.入社日
                            rd.HireDate__c							    = ConvertUtil.ConvertDateStr(rdw.NYUSHA_DATE__c);
                            //13.退社日
                            rd.RetirementDate__c		    			= ConvertUtil.ConvertDateStr(rdw.TAISHA_DATE__c);
                            //14.更新日時
                            rd.UpdateDateAndTime__c				        = rdw.MOD_DATE__c;
                            //15.更新端末
                            rd.UpdateTerminal__c				        = rdw.MOD_TERM__c;
                            
                            userMap.put(key , rd);
                        }
                    }
                }
                // Savepointの作成
                Savepoint sp = Database.setSavepoint();
                try {
                    if (!userMap.isEmpty()){
                        Database.update(userMap.values() , BatchResult.ALL_OR_NONE);
                        //update userMap.values();
                        
                        // upsertが成功したらworkを削除用に追加
                        targetStaffWorkList.addAll(staffWorkList);
                    }
                } catch(Exception e) {
                    Database.rollback(sp);
                    isErr = true;
                    msgErr += '\n' + e.getTypeName()+ ': ' + e.getMessage()+ '\n' + e.getStackTraceString();
                    //throw new BatchException(msgErr);
                }
            }catch(Exception e) {
                isErr = true;
                msgErr +='\n' + e.getTypeName()+ ': ' + e.getMessage()+ '\n' + e.getStackTraceString();
                //throw new BatchException(msgErr);
            }
        } else {
            isErr = true;
            msgErr = '[CONDITION BatchResult__c NOT MATCH] 連携区分 = M01 , 連携ステータス = 1, 連携日(数式) >= システム日付 - 8';
        }
    }
    
    global void finish(Database.BatchableContext bc){
		// ApexJobの取得
		etDtTm = Datetime.now();
		System.debug('### End Batch : StaffBatch ###');
        
        if(!isErr){
            
            // 処理結果管理レコードの作成
            // TODO 項目
            /*
            BatchResult__c result = new BatchResult__c();
            result.Batch__c = 'StaffBatch';
            result.ST_DT_TM__c = stDtTm;
            result.ET_DT_TM__c = etDtTm;
            result.TOTAL_DAT__c = totalDat;
            insert result;
            */
            
            // 正常終了したら社員情報(Work)のレコードを削除
            if (!targetStaffWorkList.isEmpty()) {
                Database.delete(targetStaffWorkList , BatchResult.ALL_OR_NONE);
                //delete targetStaffWorkList;
            }
            
            // カスタムメタデータからバッチサイズ取得
            //DataLinkageBatchSetting__mdt dlbs = [SELECT BatchSize__c FROM DataLinkageBatchSetting__mdt WHERE DeveloperName = 'AllDataLinkageBatch' LIMIT 1];

            // 次のバッチを呼び出す
            // 社員情報マスタ[M1] : StaffBatch --> 店長履歴[M2]	: ManagerHistoryBatch
            if(isCallNextBatch){
                //ManagerHistoryBatch nextBatch = new ManagerHistoryBatch();
                //Database.executeBatch(nextBatch, BatchResult.getBatchSize());
            }

        } else {
            // TODO 項目
            ErrorMessage__c err = new ErrorMessage__c();
            err.ErrorBatch__c = 'StaffBatch';    //エラーが発生したApexバッチ名
            err.ErrorMessage__c = msgErr;   // システムから受け取ったエラーメッセージ
            insert err;
        }
    }
}