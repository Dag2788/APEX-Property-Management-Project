CREATE OR REPLACE TRIGGER  "APEX$TEAM_DEV_FILES_BIU" 
          before insert or update on apex$team_dev_files
          for each row
        declare
           l_filesize_quota number := 15728640;
           l_filesize_mb    number;
        begin
          for c1 in
          (
              select
                  team_dev_fs_limit
              from
                  apex_workspaces
              where
                  workspace_id = v( 'APP_SECURITY_GROUP_ID' )
          )
          loop
            l_filesize_quota := c1.team_dev_fs_limit;
            l_filesize_mb    := l_filesize_quota/1048576;
          end loop;
          if :new."ID" is null then
            select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
          end if;
          if inserting then
           :new.created := localtimestamp;
           :new.created_by := nvl(wwv_flow.g_user,user);
           :new.updated := localtimestamp;
           :new.updated_by := nvl(wwv_flow.g_user,user);
           :new.row_version_number := 1;
         elsif updating then
           :new.row_version_number := nvl(:old.row_version_number,1) + 1;
         end if;
         if (inserting or updating) and nvl(sys.dbms_lob.getlength(:new.file_blob),0) > l_filesize_quota then
           raise_application_error(-20000, wwv_flow_lang.system_message('FILE_TOO_LARGE', trunc(l_filesize_mb)));
         end if;
         if inserting or updating then
           :new.updated := localtimestamp;
           :new.updated_by := nvl(wwv_flow.g_user,user);
         end if;
        end;
        
/
ALTER TRIGGER  "APEX$TEAM_DEV_FILES_BIU" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_ACL_T1" 
before insert or update on "APEX$_ACL"
for each row
begin
    --
    -- maintain pk and timestamps
    --
    :new.username := upper(:new.username);
    if inserting and :new.id is null then
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
    end if;
    if inserting then
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    end if;
end;
/
ALTER TRIGGER  "APEX$_ACL_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_WS_FILES_T1" 
before insert or update on "APEX$_WS_FILES"
for each row
begin
    --
    -- maintain pk and timestamps
    --
    if inserting and :new.id is null then
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
    end if;
    if inserting and :new.image_alias is null then
        :new.image_alias := :new.name;
    end if;
    if inserting then
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
        :new.content_last_update := sysdate;
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
        if nvl(length(:new.content),0) <> nvl(length(:old.content),0) then
            :new.content_last_update := sysdate;
        end if;
    end if;
end;
/
ALTER TRIGGER  "APEX$_WS_FILES_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_WS_LINKS_T1" 
before insert or update on "APEX$_WS_LINKS"
for each row
begin
    --
    -- maintain pk and timestamps
    --
    if inserting and :new.id is null then
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
    end if;
    if inserting then
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    end if;
end;
/
ALTER TRIGGER  "APEX$_WS_LINKS_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_WS_NOTES_T1" 
before insert or update on "APEX$_WS_NOTES"
for each row
begin
    --
    -- maintain pk and timestamps
    --
    if inserting and :new.id is null then
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
    end if;
    if inserting then
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    end if;
end;
/
ALTER TRIGGER  "APEX$_WS_NOTES_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_WS_ROWS_T1" 
before insert or update on "APEX$_WS_ROWS"
for each row
declare
    l_tag_list apex_application_global.vc_arr2;
    type col_arr is table of varchar2(32767) index by varchar2(255);
    la_col_label col_arr;
    procedure datagrid_logging( 
        p_row_id       in number,
        p_ws_app_id    in number,
        p_data_grid_id in number,
        p_col_name     in varchar2,
        p_type         in varchar2,
        p_old_c        in varchar2 default null,
        p_new_c        in varchar2 default null,
        p_old_d        in date default null,
        p_new_d        in date default null,
        p_old_n        in number default null,
        p_new_n        in number default null)
    is
    begin
        case p_type
        when 'C' then
          if (p_old_c is null and p_new_c is not null) or (p_old_c is not null and p_new_c is null) or (p_old_c != p_new_c) then
              insert into apex$_ws_history (row_id, ws_app_id, data_grid_id, column_name, old_value, new_value, change_date, application_user_id)
              values (p_row_id, p_ws_app_id, p_data_grid_id, p_col_name, p_old_c, p_new_c, sysdate, nvl(v('APP_USER'),user));
          end if;
        when 'D' then
          if (p_old_d is null and p_new_d is not null) or (p_old_d is not null and p_new_d is null) or (p_old_d != p_new_d) then
              insert into apex$_ws_history (row_id, ws_app_id, data_grid_id, column_name, old_value,  new_value, change_date, application_user_id)
              values (p_row_id, p_ws_app_id, p_data_grid_id, p_col_name, p_old_d, p_new_d, sysdate, nvl(v('APP_USER'),user));
        	  end if;
        when 'N' then
          if (p_old_n is null and p_new_n is not null) or (p_old_n is not null and p_new_n is null) or (p_old_n != p_new_n) then
              insert into apex$_ws_history (row_id, ws_app_id, data_grid_id, column_name, old_value,  new_value, change_date, application_user_id)
              values (p_row_id, p_ws_app_id, p_data_grid_id, p_col_name, p_old_n, p_new_n, sysdate, nvl(v('APP_USER'),user));
          end if;
        end case;
    end datagrid_logging;
    procedure wa( p_c in out nocopy clob, p_buf in varchar2 )
    is
    l_lf varchar2(2) := unistr('\000a');
    begin
    if p_buf is not null then sys.dbms_lob.writeappend( p_c, length(p_buf||l_lf), upper(p_buf)||l_lf); end if;
    end wa;
begin
    --
    -- maintain pk and timestamps
    --
    if inserting then
        if :new.id is null then
            select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
        end if;
        
        -- manintain readable row key
        if :new.unique_value is null then
            :new.unique_value := apex_util.compress_int(apex$_ws_seq.nextval);
        end if;
        
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.load_order from sys.dual;
        :new.change_count := 0;
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
        :new.change_count := :old.change_count + 1;
    end if;
    --
    -- inserting remove chr 13
    --
    if instr(:new.c001,chr(13)) > 0 then :new.c001 := replace(:new.c001,chr(13),null); end if;
    if instr(:new.c002,chr(13)) > 0 then :new.c002 := replace(:new.c002,chr(13),null); end if;
    if instr(:new.c003,chr(13)) > 0 then :new.c003 := replace(:new.c003,chr(13),null); end if;
    if instr(:new.c004,chr(13)) > 0 then :new.c004 := replace(:new.c004,chr(13),null); end if;
    if instr(:new.c005,chr(13)) > 0 then :new.c005 := replace(:new.c005,chr(13),null); end if;
    if instr(:new.c006,chr(13)) > 0 then :new.c006 := replace(:new.c006,chr(13),null); end if;
    if instr(:new.c007,chr(13)) > 0 then :new.c007 := replace(:new.c007,chr(13),null); end if;
    if instr(:new.c008,chr(13)) > 0 then :new.c008 := replace(:new.c008,chr(13),null); end if;
    if instr(:new.c009,chr(13)) > 0 then :new.c009 := replace(:new.c009,chr(13),null); end if;
    if instr(:new.c010,chr(13)) > 0 then :new.c010 := replace(:new.c010,chr(13),null); end if;
    if instr(:new.c011,chr(13)) > 0 then :new.c011 := replace(:new.c011,chr(13),null); end if;
    if instr(:new.c012,chr(13)) > 0 then :new.c012 := replace(:new.c012,chr(13),null); end if;
    if instr(:new.c013,chr(13)) > 0 then :new.c013 := replace(:new.c013,chr(13),null); end if;
    if instr(:new.c014,chr(13)) > 0 then :new.c014 := replace(:new.c014,chr(13),null); end if;
    if instr(:new.c015,chr(13)) > 0 then :new.c015 := replace(:new.c015,chr(13),null); end if;
    if instr(:new.c016,chr(13)) > 0 then :new.c016 := replace(:new.c016,chr(13),null); end if;
    if instr(:new.c017,chr(13)) > 0 then :new.c017 := replace(:new.c017,chr(13),null); end if;
    if instr(:new.c018,chr(13)) > 0 then :new.c018 := replace(:new.c018,chr(13),null); end if;
    if instr(:new.c019,chr(13)) > 0 then :new.c019 := replace(:new.c019,chr(13),null); end if;
    if instr(:new.c020,chr(13)) > 0 then :new.c020 := replace(:new.c010,chr(23),null); end if;
    if instr(:new.c021,chr(13)) > 0 then :new.c021 := replace(:new.c001,chr(23),null); end if;
    if instr(:new.c022,chr(13)) > 0 then :new.c022 := replace(:new.c002,chr(23),null); end if;
    if instr(:new.c023,chr(13)) > 0 then :new.c023 := replace(:new.c003,chr(23),null); end if;
    if instr(:new.c024,chr(13)) > 0 then :new.c024 := replace(:new.c004,chr(23),null); end if;
    if instr(:new.c025,chr(13)) > 0 then :new.c025 := replace(:new.c005,chr(23),null); end if;
    if instr(:new.c026,chr(13)) > 0 then :new.c026 := replace(:new.c006,chr(23),null); end if;
    if instr(:new.c027,chr(13)) > 0 then :new.c027 := replace(:new.c007,chr(23),null); end if;
    if instr(:new.c028,chr(13)) > 0 then :new.c028 := replace(:new.c008,chr(23),null); end if;
    if instr(:new.c029,chr(13)) > 0 then :new.c029 := replace(:new.c009,chr(23),null); end if;
    if instr(:new.c030,chr(13)) > 0 then :new.c030 := replace(:new.c030,chr(13),null); end if;
    if instr(:new.c031,chr(13)) > 0 then :new.c031 := replace(:new.c031,chr(13),null); end if;
    if instr(:new.c032,chr(13)) > 0 then :new.c032 := replace(:new.c032,chr(13),null); end if;
    if instr(:new.c033,chr(13)) > 0 then :new.c033 := replace(:new.c033,chr(13),null); end if;
    if instr(:new.c034,chr(13)) > 0 then :new.c034 := replace(:new.c034,chr(13),null); end if;
    if instr(:new.c035,chr(13)) > 0 then :new.c035 := replace(:new.c035,chr(13),null); end if;
    if instr(:new.c036,chr(13)) > 0 then :new.c036 := replace(:new.c036,chr(13),null); end if;
    if instr(:new.c037,chr(13)) > 0 then :new.c037 := replace(:new.c037,chr(13),null); end if;
    if instr(:new.c038,chr(13)) > 0 then :new.c038 := replace(:new.c038,chr(13),null); end if;
    if instr(:new.c039,chr(13)) > 0 then :new.c039 := replace(:new.c039,chr(13),null); end if;
    if instr(:new.c040,chr(13)) > 0 then :new.c040 := replace(:new.c040,chr(13),null); end if;
    if instr(:new.c041,chr(13)) > 0 then :new.c041 := replace(:new.c041,chr(13),null); end if;
    if instr(:new.c042,chr(13)) > 0 then :new.c042 := replace(:new.c042,chr(13),null); end if;
    if instr(:new.c043,chr(13)) > 0 then :new.c043 := replace(:new.c043,chr(13),null); end if;
    if instr(:new.c044,chr(13)) > 0 then :new.c044 := replace(:new.c044,chr(13),null); end if;
    if instr(:new.c045,chr(13)) > 0 then :new.c045 := replace(:new.c045,chr(13),null); end if;
    if instr(:new.c046,chr(13)) > 0 then :new.c046 := replace(:new.c046,chr(13),null); end if;
    if instr(:new.c047,chr(13)) > 0 then :new.c047 := replace(:new.c047,chr(13),null); end if;
    if instr(:new.c048,chr(13)) > 0 then :new.c048 := replace(:new.c048,chr(13),null); end if;
    if instr(:new.c049,chr(13)) > 0 then :new.c049 := replace(:new.c049,chr(13),null); end if;
    if instr(:new.c050,chr(13)) > 0 then :new.c050 := replace(:new.c050,chr(13),null); end if;
    if :new.search_clob is null then
        sys.dbms_lob.createtemporary( :new.search_clob, false, sys.dbms_lob.session );
    else
        sys.dbms_lob.trim( :new.search_clob, 0 );
    end if;
    wa(:new.search_clob,:new.c001);wa(:new.search_clob,:new.c002);wa(:new.search_clob,:new.c003);
    wa(:new.search_clob,:new.c004);wa(:new.search_clob,:new.c005);wa(:new.search_clob,:new.c006);
    wa(:new.search_clob,:new.c007);wa(:new.search_clob,:new.c008);wa(:new.search_clob,:new.c009);
    wa(:new.search_clob,:new.c010);wa(:new.search_clob,:new.c011);wa(:new.search_clob,:new.c012);
    wa(:new.search_clob,:new.c013);wa(:new.search_clob,:new.c014);wa(:new.search_clob,:new.c015);
    wa(:new.search_clob,:new.c016);wa(:new.search_clob,:new.c017);wa(:new.search_clob,:new.c018);
    wa(:new.search_clob,:new.c019);wa(:new.search_clob,:new.c020);wa(:new.search_clob,:new.c021);
    wa(:new.search_clob,:new.c022);wa(:new.search_clob,:new.c023);wa(:new.search_clob,:new.c024);
    wa(:new.search_clob,:new.c025);wa(:new.search_clob,:new.c026);wa(:new.search_clob,:new.c027);
    wa(:new.search_clob,:new.c028);wa(:new.search_clob,:new.c029);wa(:new.search_clob,:new.c030);
    wa(:new.search_clob,:new.c031);wa(:new.search_clob,:new.c032);wa(:new.search_clob,:new.c033);
    wa(:new.search_clob,:new.c034);wa(:new.search_clob,:new.c035);wa(:new.search_clob,:new.c036);
    wa(:new.search_clob,:new.c037);wa(:new.search_clob,:new.c038);wa(:new.search_clob,:new.c039);
    wa(:new.search_clob,:new.c040);wa(:new.search_clob,:new.c041);wa(:new.search_clob,:new.c042);
    wa(:new.search_clob,:new.c043);wa(:new.search_clob,:new.c044);wa(:new.search_clob,:new.c045);
    wa(:new.search_clob,:new.c046);wa(:new.search_clob,:new.c047);wa(:new.search_clob,:new.c048);
    wa(:new.search_clob,:new.c049);wa(:new.search_clob,:new.c050);
    --
    -- history
    --
    if updating then
       -- initialize column label array
       for i in 1..50
       loop
           la_col_label('C'||to_char(i,'FM009')) := null;
           la_col_label('N'||to_char(i,'FM009')) := null;
           la_col_label('D'||to_char(i,'FM009')) := null;
       end loop;
       -- get column label array
       for c1 in (select column_alias, report_label 
                  from apex_ws_data_grid_col
                  where data_grid_id = :new.data_grid_id)
       loop
           la_col_label(c1.column_alias) := c1.report_label;
       end loop;
       -- strings
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C001'),'C',:old.c001,:new.c001);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C002'),'C',:old.c002,:new.c002);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C003'),'C',:old.c003,:new.c003);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C004'),'C',:old.c004,:new.c004);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C005'),'C',:old.c005,:new.c005);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C006'),'C',:old.c006,:new.c006);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C007'),'C',:old.c007,:new.c007);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C008'),'C',:old.c008,:new.c008);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C009'),'C',:old.c009,:new.c009);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C010'),'C',:old.c010,:new.c010);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C011'),'C',:old.c011,:new.c011);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C012'),'C',:old.c012,:new.c012);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C013'),'C',:old.c013,:new.c013);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C014'),'C',:old.c014,:new.c014);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C015'),'C',:old.c015,:new.c015);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C016'),'C',:old.c016,:new.c016);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C017'),'C',:old.c017,:new.c017);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C018'),'C',:old.c018,:new.c018);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C019'),'C',:old.c019,:new.c019);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C020'),'C',:old.c020,:new.c020);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C021'),'C',:old.c021,:new.c021);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C022'),'C',:old.c022,:new.c022);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C023'),'C',:old.c023,:new.c023);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C024'),'C',:old.c024,:new.c024);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C025'),'C',:old.c025,:new.c025);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C026'),'C',:old.c026,:new.c026);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C027'),'C',:old.c027,:new.c027);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C028'),'C',:old.c028,:new.c028);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C029'),'C',:old.c029,:new.c029);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C030'),'C',:old.c030,:new.c030);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C031'),'C',:old.c031,:new.c031);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C032'),'C',:old.c032,:new.c032);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C033'),'C',:old.c033,:new.c033);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C034'),'C',:old.c034,:new.c034);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C035'),'C',:old.c035,:new.c035);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C036'),'C',:old.c036,:new.c036);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C037'),'C',:old.c037,:new.c037);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C038'),'C',:old.c038,:new.c038);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C039'),'C',:old.c039,:new.c039);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C040'),'C',:old.c040,:new.c040);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C041'),'C',:old.c041,:new.c041);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C042'),'C',:old.c042,:new.c042);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C043'),'C',:old.c043,:new.c043);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C044'),'C',:old.c044,:new.c044);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C045'),'C',:old.c045,:new.c045);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C046'),'C',:old.c046,:new.c046);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C047'),'C',:old.c047,:new.c047);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C048'),'C',:old.c048,:new.c048);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C049'),'C',:old.c049,:new.c049);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('C050'),'C',:old.c050,:new.c050);
       -- numbers
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N001'),'N',null,null,null,null,:old.n001,:new.n001);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N002'),'N',null,null,null,null,:old.n002,:new.n002);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N003'),'N',null,null,null,null,:old.n003,:new.n003);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N004'),'N',null,null,null,null,:old.n004,:new.n004);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N005'),'N',null,null,null,null,:old.n005,:new.n005);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N006'),'N',null,null,null,null,:old.n006,:new.n006);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N007'),'N',null,null,null,null,:old.n007,:new.n007);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N008'),'N',null,null,null,null,:old.n008,:new.n008);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N009'),'N',null,null,null,null,:old.n009,:new.n009);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N010'),'N',null,null,null,null,:old.n010,:new.n010);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N011'),'N',null,null,null,null,:old.n011,:new.n011);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N012'),'N',null,null,null,null,:old.n012,:new.n012);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N013'),'N',null,null,null,null,:old.n013,:new.n013);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N014'),'N',null,null,null,null,:old.n014,:new.n014);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N015'),'N',null,null,null,null,:old.n015,:new.n015);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N016'),'N',null,null,null,null,:old.n016,:new.n016);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N017'),'N',null,null,null,null,:old.n017,:new.n017);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N018'),'N',null,null,null,null,:old.n018,:new.n018);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N019'),'N',null,null,null,null,:old.n019,:new.n019);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N020'),'N',null,null,null,null,:old.n020,:new.n020);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N021'),'N',null,null,null,null,:old.n021,:new.n021);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N022'),'N',null,null,null,null,:old.n022,:new.n022);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N023'),'N',null,null,null,null,:old.n023,:new.n023);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N024'),'N',null,null,null,null,:old.n024,:new.n024);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N025'),'N',null,null,null,null,:old.n025,:new.n025);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N026'),'N',null,null,null,null,:old.n026,:new.n026);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N027'),'N',null,null,null,null,:old.n027,:new.n027);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N028'),'N',null,null,null,null,:old.n028,:new.n028);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N029'),'N',null,null,null,null,:old.n029,:new.n029);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N030'),'N',null,null,null,null,:old.n030,:new.n030);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N031'),'N',null,null,null,null,:old.n031,:new.n031);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N032'),'N',null,null,null,null,:old.n032,:new.n032);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N033'),'N',null,null,null,null,:old.n033,:new.n033);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N034'),'N',null,null,null,null,:old.n034,:new.n034);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N035'),'N',null,null,null,null,:old.n035,:new.n035);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N036'),'N',null,null,null,null,:old.n036,:new.n036);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N037'),'N',null,null,null,null,:old.n037,:new.n037);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N038'),'N',null,null,null,null,:old.n038,:new.n038);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N039'),'N',null,null,null,null,:old.n039,:new.n039);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N040'),'N',null,null,null,null,:old.n040,:new.n040);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N041'),'N',null,null,null,null,:old.n041,:new.n041);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N042'),'N',null,null,null,null,:old.n042,:new.n042);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N043'),'N',null,null,null,null,:old.n043,:new.n043);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N044'),'N',null,null,null,null,:old.n044,:new.n044);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N045'),'N',null,null,null,null,:old.n045,:new.n045);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N046'),'N',null,null,null,null,:old.n046,:new.n046);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N047'),'N',null,null,null,null,:old.n047,:new.n047);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N048'),'N',null,null,null,null,:old.n048,:new.n048);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N049'),'N',null,null,null,null,:old.n049,:new.n049);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('N050'),'N',null,null,null,null,:old.n050,:new.n050);
       -- dates
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D001'),'D',null,null,:old.d001,:new.d001);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D002'),'D',null,null,:old.d002,:new.d002);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D003'),'D',null,null,:old.d003,:new.d003);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D004'),'D',null,null,:old.d004,:new.d004);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D005'),'D',null,null,:old.d005,:new.d005);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D006'),'D',null,null,:old.d006,:new.d006);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D007'),'D',null,null,:old.d007,:new.d007);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D008'),'D',null,null,:old.d008,:new.d008);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D009'),'D',null,null,:old.d009,:new.d009);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D010'),'D',null,null,:old.d010,:new.d010);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D011'),'D',null,null,:old.d011,:new.d011);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D012'),'D',null,null,:old.d012,:new.d012);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D013'),'D',null,null,:old.d013,:new.d013);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D014'),'D',null,null,:old.d014,:new.d014);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D015'),'D',null,null,:old.d015,:new.d015);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D016'),'D',null,null,:old.d016,:new.d016);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D017'),'D',null,null,:old.d017,:new.d017);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D018'),'D',null,null,:old.d018,:new.d018);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D019'),'D',null,null,:old.d019,:new.d019);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D020'),'D',null,null,:old.d020,:new.d020);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D021'),'D',null,null,:old.d021,:new.d021);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D022'),'D',null,null,:old.d022,:new.d022);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D023'),'D',null,null,:old.d023,:new.d023);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D024'),'D',null,null,:old.d024,:new.d024);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D025'),'D',null,null,:old.d025,:new.d025);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D026'),'D',null,null,:old.d026,:new.d026);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D027'),'D',null,null,:old.d027,:new.d027);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D028'),'D',null,null,:old.d028,:new.d028);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D029'),'D',null,null,:old.d029,:new.d029);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D030'),'D',null,null,:old.d030,:new.d030);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D031'),'D',null,null,:old.d031,:new.d031);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D032'),'D',null,null,:old.d032,:new.d032);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D033'),'D',null,null,:old.d033,:new.d033);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D034'),'D',null,null,:old.d034,:new.d034);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D035'),'D',null,null,:old.d035,:new.d035);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D036'),'D',null,null,:old.d036,:new.d036);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D037'),'D',null,null,:old.d037,:new.d037);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D038'),'D',null,null,:old.d038,:new.d038);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D039'),'D',null,null,:old.d039,:new.d039);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D040'),'D',null,null,:old.d040,:new.d040);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D041'),'D',null,null,:old.d041,:new.d041);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D042'),'D',null,null,:old.d042,:new.d042);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D043'),'D',null,null,:old.d043,:new.d043);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D044'),'D',null,null,:old.d044,:new.d044);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D045'),'D',null,null,:old.d045,:new.d045);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D046'),'D',null,null,:old.d046,:new.d046);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D047'),'D',null,null,:old.d047,:new.d047);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D048'),'D',null,null,:old.d048,:new.d048);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D049'),'D',null,null,:old.d049,:new.d049);
       datagrid_logging(:new.id,:new.ws_app_id,:new.data_grid_id,la_col_label('D050'),'D',null,null,:old.d050,:new.d050);
    end if;
    --
    -- set owner
    --
    if :new.owner is null then
        :new.owner := :new.created_by;
    end if;
end;

/
ALTER TRIGGER  "APEX$_WS_ROWS_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_WS_TAGS_T1" 
before insert or update on "APEX$_WS_TAGS"
for each row
begin
    --
    -- maintain pk and timestamps
    --
    if inserting and :new.id is null then
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
    end if;
    if inserting then
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
    end if;
end;
/
ALTER TRIGGER  "APEX$_WS_TAGS_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_CUSTOMERS_BD" 
    before delete on demo_customers
    for each row
begin
    sample_pkg.demo_tag_sync(
        p_new_tags      => null,
        p_old_tags      => :old.tags,
        p_content_type  => 'CUSTOMER',
        p_content_id    => :old.customer_id );
end;

/
ALTER TRIGGER  "DEMO_CUSTOMERS_BD" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_CUSTOMERS_BIU" 
  before insert or update ON demo_customers FOR EACH ROW
DECLARE
  cust_id number;
BEGIN
  if inserting then  
    if :new.customer_id is null then
      select demo_cust_seq.nextval
        into cust_id
        from dual;
      :new.customer_id := cust_id;
    end if;
    if :new.tags is not null then
          :new.tags := sample_pkg.demo_tags_cleaner(:new.tags);
    end if;
  end if;
  sample_pkg.demo_tag_sync(
     p_new_tags      => :new.tags,
     p_old_tags      => :old.tags,
     p_content_type  => 'CUSTOMER',
     p_content_id    => :new.customer_id );
END;

/
ALTER TRIGGER  "DEMO_CUSTOMERS_BIU" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_ORDERS_BD" 
    before delete on demo_orders
    for each row
begin
    sample_pkg.demo_tag_sync(
        p_new_tags      => null,
        p_old_tags      => :old.tags,
        p_content_type  => 'ORDER',
        p_content_id    => :old.order_id );
end;

/
ALTER TRIGGER  "DEMO_ORDERS_BD" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_ORDERS_BIU" 
  before insert or update ON demo_orders FOR EACH ROW
DECLARE
  order_id number;
BEGIN
  if inserting then  
    if :new.order_id is null then
      select demo_ord_seq.nextval
        INTO order_id
        FROM dual;
      :new.order_id := order_id;
    end if;
    if :new.tags is not null then
       :new.tags := sample_pkg.demo_tags_cleaner(:new.tags);
    end if;
  end if;
  
  sample_pkg.demo_tag_sync(
    p_new_tags      => :new.tags,
    p_old_tags      => :old.tags,
    p_content_type  => 'ORDER',
    p_content_id    => :new.order_id );
END;

/
ALTER TRIGGER  "DEMO_ORDERS_BIU" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_ORDER_ITEMS_AIUD_TOTAL" 
  after insert or update or delete on demo_order_items
begin
  -- Update the Order Total when any order item is changed
  update demo_orders set order_total =
  (select sum(unit_price*quantity) from demo_order_items
    where demo_order_items.order_id = demo_orders.order_id);
end;

/
ALTER TRIGGER  "DEMO_ORDER_ITEMS_AIUD_TOTAL" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_ORDER_ITEMS_BI" 
  BEFORE insert on "DEMO_ORDER_ITEMS" for each row
declare
  order_item_id number;
begin
  if :new.order_item_id is null then
    select demo_order_items_seq.nextval 
      into order_item_id 
      from dual;
    :new.order_item_id := order_item_id;
  end if;
end;

/
ALTER TRIGGER  "DEMO_ORDER_ITEMS_BI" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_ORDER_ITEMS_BIU_GET_PRICE" 
  before insert or update on demo_order_items for each row
declare
  l_list_price number;
begin
  if :new.unit_price is null then
    -- First, we need to get the current list price of the order line item
    select list_price
    into l_list_price
    from demo_product_info
    where product_id = :new.product_id;
    -- Once we have the correct price, we will update the order line with the correct price
    :new.unit_price := l_list_price;
  end if;
end;

/
ALTER TRIGGER  "DEMO_ORDER_ITEMS_BIU_GET_PRICE" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_PRODUCT_INFO_BD" 
    before delete on demo_product_info
    for each row
begin
    sample_pkg.demo_tag_sync(
        p_new_tags      => null,
        p_old_tags      => :old.tags,
        p_content_type  => 'PRODUCT',
        p_content_id    => :old.product_id );
end;

/
ALTER TRIGGER  "DEMO_PRODUCT_INFO_BD" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_PRODUCT_INFO_BIU" 
  before insert or update ON demo_product_info FOR EACH ROW
DECLARE
  prod_id number;
BEGIN
  if inserting then  
    if :new.product_id is null then
      select demo_prod_seq.nextval
        into prod_id
        from dual;
      :new.product_id := prod_id;
    end if;
    if :new.tags is not null then
          :new.tags := sample_pkg.demo_tags_cleaner(:new.tags);
    end if;
  end if;
  sample_pkg.demo_tag_sync(
    p_new_tags      => :new.tags,
    p_old_tags      => :old.tags,
    p_content_type  => 'PRODUCT',
    p_content_id    => :new.product_id );
END;

/
ALTER TRIGGER  "DEMO_PRODUCT_INFO_BIU" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEMO_TAGS_BIU" 
   before insert or update on demo_tags
   for each row
   begin
      if inserting then
         if :NEW.ID is null then
           select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX')
           into :new.id
           from dual;
         end if;
         :NEW.CREATED := localtimestamp;
         :NEW.CREATED_BY := nvl(v('APP_USER'),USER);
      end if;
      if updating then
         :NEW.UPDATED := localtimestamp;
         :NEW.UPDATED_BY := nvl(v('APP_USER'),USER);
      end if;
end;

/
ALTER TRIGGER  "DEMO_TAGS_BIU" ENABLE
/
CREATE OR REPLACE TRIGGER  "DEPT_TRG1" 
              before insert on dept
              for each row
              begin
                  if :new.deptno is null then
                      select dept_seq.nextval into :new.deptno from sys.dual;
                 end if;
              end;
/
ALTER TRIGGER  "DEPT_TRG1" ENABLE
/
CREATE OR REPLACE TRIGGER  "EMP_TRG1" 
              before insert on emp
              for each row
              begin
                  if :new.empno is null then
                      select emp_seq.nextval into :new.empno from sys.dual;
                 end if;
              end;
/
ALTER TRIGGER  "EMP_TRG1" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_APPROVALS_AUD_TRIG" 
before insert or update on NPM_approvals 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_APPROVALS_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "APEX$_WS_WEBPG_SECTIONS_T1" 
before insert or update on "APEX$_WS_WEBPG_SECTIONS"
for each row
declare
    l_sequence_changed varchar2(1) := 'N';
    l_title_changed varchar2(1) := 'N';
    l_content_changed varchar2(1) := 'N';
    procedure clob_upper( p_content in clob, p_content_upper in out nocopy clob)
    is
    l_buf varchar2(32767);
    l_off number;
    l_amt number;
    begin
    if p_content is not null then
        l_amt := 8000;
        l_off := 1;
         sys.dbms_lob.trim( p_content_upper, 0);
         begin
             loop
                 sys.dbms_lob.read( p_content, l_amt, l_off, l_buf );
                 l_buf := upper( l_buf );
                 sys.dbms_lob.writeappend( p_content_upper, length(l_buf), l_buf);
                 l_off := l_off + l_amt;
                 l_amt := 8000;
             end loop;
         exception
             when no_data_found then null;
         end;
     end if;
end clob_upper;
begin
    --
    -- maintain pk and timestamps
    --
    if inserting and :new.id is null then
        select to_number(sys_guid(),'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') into :new.id from sys.dual;
    end if;
    if :new.section_type = 'NAV_PAGE' then
        if :new.nav_include_link is null then
            :new.nav_include_link := 'Y';
        end if;
    end if;
    if inserting and :new.content is not null then
        sys.dbms_lob.createtemporary( :new.content_upper, false, sys.dbms_lob.call );
        clob_upper( :new.content, :new.content_upper );
    elsif updating then
        if :new.content_upper is null then
            sys.dbms_lob.createtemporary( :new.content_upper, false, sys.dbms_lob.call );
        end if;
        clob_upper( :new.content, :new.content_upper );
    end if;
    if inserting then
        :new.created_on := sysdate;
        :new.created_by := nvl(v('APP_USER'),user);
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
        :new.change_count := 0;
    elsif updating then
        :new.updated_on := sysdate;
        :new.updated_by := nvl(v('APP_USER'),user);
        :new.change_count := nvl(:old.change_count,0) + 1;
        if nvl(:old.display_sequence,-999) != nvl(:new.display_sequence,-999) then
            l_sequence_changed := 'Y';
        end if;
        if nvl(:old.title,'jKKwZk') != nvl(:new.title,'jKKwZk') then
            l_title_changed := 'Y';
        end if;
        if sys.dbms_lob.compare(:new.content,:old.content) != 0 or nvl(length(:new.content),0) != nvl(length(:old.content),0) then
            l_content_changed := 'Y';
        end if;
        if l_sequence_changed = 'Y' or l_title_changed = 'Y' or l_content_changed = 'Y' then
            insert into apex$_ws_webpg_section_history (section_id, ws_app_id, webpage_id, old_display_sequence, new_display_sequence,
            old_title, new_title, old_content, new_content, change_date, application_user_id)
            values (:new.id, :new.ws_app_id, :new.webpage_id,
                    decode(l_sequence_changed,'Y',:old.display_sequence,null), decode(l_sequence_changed,'Y',:new.display_sequence,null),
                    decode(l_title_changed,'Y',:old.title,null), decode(l_title_changed,'Y',:new.title,null),
                    decode(l_content_changed,'Y',:old.content,null), decode(l_content_changed,'Y',:new.content,null), sysdate, nvl(v('APP_USER'),user));
        end if;
    end if;
end;
/
ALTER TRIGGER  "APEX$_WS_WEBPG_SECTIONS_T1" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREEMENTS_AUD_TRIG" 
before insert or update on NPM_agreements 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_AGREEMENTS_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREE_APP_AUD_TRIG" 
before insert or update on NPM_Agree_App 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_AGREE_APP_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREE_TRIG_AUD_TRIG" 
before insert or update on NPM_Agree_Trig 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_AGREE_TRIG_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREEMENTS_PK_TRIG" 
before insert on NPM_agreements
for each row 
declare
type version_table IS TABLE OF NPM_agreements.version%type;
t_version version_table;
begin 
--get agreement id from sequence
select NPM_agreements_seq.nextval into :new.agreement_id from dual;
--get contract number from sequence (if null)
IF :NEW.CONTRACT_NUMBER is NULL THEN
select NPM_CONTRACT_NUMBER_SEQ.nextval into :NEW.CONTRACT_NUMBER from dual;
END IF;
--set version parent to it's own agreement id (if null)
IF :NEW.VERSION_PARENT is NULL THEN
:NEW.VERSION_PARENT := :NEW.AGREEMENT_ID;
END IF;
--set dept_former_name_id (if null) based on current department name
IF :NEW.DEPT_FORMER_NAME_ID is NULL AND :NEW.DEPARTMENT_ID IS NOT NULL THEN
select n.name_id into :NEW.DEPT_FORMER_NAME_ID from NPM_former_name n where n.department_id = :NEW.DEPARTMENT_ID and upper(n.CURRENT_NAME) = 'Y';
END IF;
--set ven_former_name_id (if null) based on current vendor name
IF :NEW.VEN_FORMER_NAME_ID is NULL AND :NEW.VENDOR_ID IS NOT NULL THEN
select n.name_id into :NEW.VEN_FORMER_NAME_ID from NPM_former_name n where n.vendor_id = :NEW.VENDOR_ID and upper(n.CURRENT_NAME) = 'Y';
END IF;
--set version to 0 (if null)
IF :NEW.VERSION is NULL THEN
select 0 into :NEW.VERSION from dual;
ELSE 
  --throw an error if inserting a duplicate version
  SELECT version
  BULK COLLECT INTO t_version 
  FROM NPM_agreements 
  WHERE version_parent = :NEW.VERSION_PARENT AND version = :NEW.VERSION;
  IF t_version.count() != 0 then
    RAISE_APPLICATION_ERROR(-20001, 'Duplicate version.');
  END IF;
END IF;
:NEW.DATE_ACCESSED := SYSDATE;
end; 

/
ALTER TRIGGER  "NPM_AGREEMENTS_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREE_APP_TRIG" 
BEFORE
insert on "NPM_AGREE_APP"
for each row
begin
select NPM_agree_app_seq.nextval into :new.agree_app_id from dual; 
end;

/
ALTER TRIGGER  "NPM_AGREE_APP_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREE_APP_TRIG_APPROVAL" 
FOR 
insert on "NPM_AGREE_APP"
COMPOUND TRIGGER
  agreement_var NUMBER;
  count_num NUMBER;
BEFORE EACH ROW IS
begin
 agreement_var := :new.agreement_id;
end before each row;
AFTER STATEMENT IS 
CURSOR approvals_cursor is 
   Select agreement_id, approval_id, agree_app_id from NPM_agree_app
   Where agreement_var = agreement_id; 
BEGIN 
For cursor_row In approvals_cursor LOOP
   select count(approval_id) into count_num from NPM_agree_app
    Where cursor_row.approval_id = approval_id and agreement_id = agreement_var;
   if count_num >= 2 THEN
     DELETE FROM NPM_AGREE_APP Where agree_app_id = cursor_row.agree_app_id;
   end if; 
 
END LOOP; 
END AFTER STATEMENT;
END;

/
ALTER TRIGGER  "NPM_AGREE_APP_TRIG_APPROVAL" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREE_TRIG_PK_TRIG" 
before insert on NPM_AGREE_TRIG
for each row
declare
  store_proc VARCHAR(500);
  store_proc_name VARCHAR(100);
begin 
select NPM_AGREE_TRIG_seq.nextval into :new.agree_trig_id from dual;
select sql_insert into store_proc_name from NPM_TRIGGERS where trigger_id = :new.trigger_id;
store_proc := 'BEGIN ' || store_proc_name || '(:agid); END;';
EXECUTE IMMEDIATE store_proc USING :new.agreement_id;
end;

/
ALTER TRIGGER  "NPM_AGREE_TRIG_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_AGREE_APP_PK_TRIG" 
before insert on NPM_Agree_App
for each row 
begin 
select NPM_Agree_App_seq.nextval into :new.agree_app_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_AGREE_APP_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_APPROVALS_PK_TRIG" 
before insert on NPM_approvals
for each row 
begin 
select NPM_approvals_seq.nextval into :new.approval_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_APPROVALS_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_BORDATES_AUD_TRIG" 
before insert or update on NPM_Bordates 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_BORDATES_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_BORDATES_PK_TRIG" 
before insert on NPM_Bordates
for each row 
begin 
select NPM_Bordates_seq.nextval into :new.bordate_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_BORDATES_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_BUILDING_PK_TRIG" 
before insert on NPM_building
for each row 
begin 
select NPM_building_seq.nextval into :new.building_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_BUILDING_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DEPARTMENT_AUD_TRIG" 
before insert or update on NPM_department 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_DEPARTMENT_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_BUILDING_AUD_TRIG" 
before insert or update on NPM_building 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_BUILDING_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_CONTACT_AUD_TRIG" 
before insert or update on NPM_contact 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_CONTACT_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_CONTACT_PK_TRIG" 
before insert on NPM_contact
for each row 
begin 
select NPM_contact_seq.nextval into :new.contact_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_CONTACT_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DEPARTMENT_FORMER_NAME" 
after insert on NPM_department
for each row 
begin
insert into NPM_FORMER_NAME (name, department_id, current_name)
VALUES (:new.name, :new.department_id, 'y'); 
end;

/
ALTER TRIGGER  "NPM_DEPARTMENT_FORMER_NAME" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DEPARTMENT_PK_TRIG" 
before insert on NPM_department
for each row 
begin 
select NPM_department_seq.nextval into :new.department_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_DEPARTMENT_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DEPARTMENT_UPDATE_NAME" 
after update on NPM_department
for each row 
begin
if :new.name != :old.name THEN 
   update NPM_FORMER_NAME set current_name = 'n' where department_id = :new.department_id; 
   insert into NPM_FORMER_NAME (name, department_id, current_name)
   VALUES (:new.name, :new.department_id, 'y'); 
end if; 
end;

/
ALTER TRIGGER  "NPM_DEPARTMENT_UPDATE_NAME" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DOCUMENT_AGREE_APP_TRIG" 
AFTER INSERT OR UPDATE
ON NPM_DOCUMENT
For each row
BEGIN
IF :new.agree_app_id IS NOT NULL THEN
UPDATE NPM_Agree_App
SET complete = 'y'
WHERE agree_app_id = :new.agree_app_id; 
END IF;
END;

/
ALTER TRIGGER  "NPM_DOCUMENT_AGREE_APP_TRIG" DISABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DOCUMENT_AUD_TRIG" 
before insert or update on NPM_document 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_DOCUMENT_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_DOCUMENT_PK_TRIG" 
before insert or update on NPM_document
for each row 
begin 
IF :new.document_id is NULL THEN
select NPM_document_seq.nextval into :new.document_id from dual;
END IF;
IF :new.agree_app_id IS NOT NULL THEN
UPDATE NPM_Agree_App
SET complete = 'y'
WHERE agree_app_id = :new.agree_app_id; 
END IF;
end; 

/
ALTER TRIGGER  "NPM_DOCUMENT_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_EMAIL_AUD_TRIG" 
before insert or update on NPM_email 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_EMAIL_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_EMAIL_PK_TRIG" 
before insert on NPM_email
for each row 
begin 
select NPM_email_seq.nextval into :new.email_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_EMAIL_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_FLOOR_AUD_TRIG" 
before insert or update on NPM_floor 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_FLOOR_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_FLOOR_PK_TRIG" 
before insert on NPM_floor
for each row 
begin 
select NPM_floor_seq.nextval into :new.floor_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_FLOOR_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_FORMER_NAME_AUD_TRIG" 
before insert or update on NPM_former_name 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_FORMER_NAME_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_FORMER_NAME_PK_TRIG" 
before insert on NPM_former_name
for each row 
begin 
select NPM_former_name_seq.nextval into :new.name_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_FORMER_NAME_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_PROPERTY_AUD_TRIG" 
before insert or update on NPM_Property 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_PROPERTY_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_PROPERTY_PK_TRIG" 
before insert on NPM_Property
for each row 
begin 
select NPM_Property_seq.nextval into :new.property_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_PROPERTY_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_STATE_AUD_TRIG" 
before insert or update on NPM_State 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_STATE_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_STATE_PK_TRIG" 
before insert on NPM_State
for each row 
begin 
select NPM_State_seq.nextval into :new.state_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_STATE_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_TICKLERS_AUD_TRIG" 
before insert or update on NPM_ticklers 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_TICKLERS_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_TICKLERS_PK_TRIG" 
before insert on NPM_ticklers
for each row 
begin 
select NPM_ticklers_seq.nextval into :new.tickler_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_TICKLERS_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_TRIGGERS_AUD_TRIG" 
before insert or update on NPM_Triggers 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_TRIGGERS_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_TRIGGERS_PK_TRIG" 
before insert on NPM_Triggers
for each row 
begin 
select NPM_Triggers_seq.nextval into :new.trigger_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_TRIGGERS_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_VENDOR_AUD_TRIG" 
before insert or update on NPM_vendor 
for each row 
begin 
  if inserting then 
    :new.created := localtimestamp; 
    :new.created_by := nvl(wwv_flow.g_user,user); 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
    :new.row_version_number := 1; 
  elsif updating then 
    :new.row_version_number := nvl(:old.row_version_number,1) + 1; 
  end if; 
  if inserting or updating then 
    :new.updated := localtimestamp; 
    :new.updated_by := nvl(wwv_flow.g_user,user); 
  end if; 
end; 

/
ALTER TRIGGER  "NPM_VENDOR_AUD_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_VENDOR_FORMER_NAME" 
after insert on NPM_vendor
for each row 
begin
insert into NPM_FORMER_NAME (name, vendor_id, current_name)
VALUES (:new.name, :new.vendor_id, 'y'); 
end;

/
ALTER TRIGGER  "NPM_VENDOR_FORMER_NAME" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_VENDOR_PK_TRIG" 
before insert on NPM_vendor
for each row 
begin 
select NPM_vendor_seq.nextval into :new.vendor_id from dual; 
end; 

/
ALTER TRIGGER  "NPM_VENDOR_PK_TRIG" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_VENDOR_UPDATE_NAME" 
after update on NPM_vendor
for each row 
begin
if :new.name != :old.name THEN 
   update NPM_FORMER_NAME set current_name = 'n' where vendor_id = :new.vendor_id; 
   insert into NPM_FORMER_NAME (name, vendor_id, current_name)
   VALUES (:new.name, :new.vendor_id, 'y'); 
end if; 
end;

/
ALTER TRIGGER  "NPM_VENDOR_UPDATE_NAME" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_PHY_ROOM_TRIGGER" 
     INSTEAD OF insert ON NPM_phy_room
     FOR EACH ROW
BEGIN
     insert into NPM_property(
    PROPERTY_ID,
    PROPERTY_TYPE,
    PHY_UNIT_NAME,
    PHY_ROOM_NAME,
    PRICE,
    BUILDING_ID,
    FLOOR_ID,
    PROPERTY_ID1)
     VALUES (
    :NEW.PROPERTY_ID,
    'Physical Room',
    :NEW.PHY_UNIT_NAME,
    :NEW.PHY_ROOM_NAME,
    :NEW.PRICE,
    :NEW.BUILDING_ID,
    :NEW.FLOOR_ID,
    :NEW.PROPERTY_ID1) ;
END;

/
ALTER TRIGGER  "NPM_PHY_ROOM_TRIGGER" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_PHY_UNIT_TRIGGER" 
     INSTEAD OF insert ON NPM_phy_unit
     FOR EACH ROW
BEGIN
     insert into NPM_property( 
    PROPERTY_ID,
    PROPERTY_TYPE,
    PHY_UNIT_NAME,
    BUILDING_ID,
    FLOOR_ID,
    PROPERTY_ID1)
     VALUES ( 
    :NEW.PROPERTY_ID,
    'Physical Unit',
    :NEW.PHY_UNIT_NAME,
    :NEW.BUILDING_ID,
    :NEW.FLOOR_ID,
    :NEW.PROPERTY_ID1) ;
END;

/
ALTER TRIGGER  "NPM_PHY_UNIT_TRIGGER" ENABLE
/
CREATE OR REPLACE TRIGGER  "NPM_LOG_UNIT_TRIGGER" 
     INSTEAD OF insert ON NPM_log_unit
     FOR EACH ROW
BEGIN
     insert into NPM_property( 
    PROPERTY_ID,
    PROPERTY_TYPE,
    LEASE_TYPE,
    LOG_UNIT_NAME,
    PHY_UNIT_NAME,
    PHY_ROOM_NAME,
    START_DATE,
    END_DATE,
    BUILDING_ID,
    FLOOR_ID,
    PROPERTY_ID1,
    AGREEMENT_ID)
     VALUES ( 
    :NEW.PROPERTY_ID,
    'Logical Unit',
    :NEW.LEASE_TYPE,
    :NEW.LOG_UNIT_NAME,
    :NEW.PHY_UNIT_NAME,
    :NEW.PHY_ROOM_NAME,
    :NEW.START_DATE,
    :NEW.END_DATE,
    :NEW.BUILDING_ID,
    :NEW.FLOOR_ID,
    :NEW.PROPERTY_ID1,
    :NEW.AGREEMENT_ID) ;
END;

/
ALTER TRIGGER  "NPM_LOG_UNIT_TRIGGER" ENABLE
/

CREATE TABLE  "NPM_VENDOR" 
   (  "VENDOR_ID" NUMBER(*,0) NOT NULL ENABLE, 
  "CURRENT_NAME_ID" NUMBER, 
  "NAME" VARCHAR2(255), 
  "STREET_ADDRESS" VARCHAR2(400), 
  "CITY" VARCHAR2(100), 
  "STATE" VARCHAR2(50), 
  "COUNTRY" VARCHAR2(300), 
  "CREATED" DATE, 
  "CREATED_BY" VARCHAR2(255), 
  "ROW_VERSION_NUMBER" NUMBER(*,0), 
  "UPDATED" DATE, 
  "UPDATED_BY" VARCHAR2(255), 
   CONSTRAINT "UTBC_VENDOR_PK" PRIMARY KEY ("VENDOR_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_VENDOR" ADD CONSTRAINT "VEN_CUR_NAME" FOREIGN KEY ("CURRENT_NAME_ID")
    REFERENCES  "NPM_FORMER_NAME" ("NAME_ID") ENABLE
/

CREATE TABLE  "NPM_TRIGGERS" 
   (  "TRIGGER_ID" NUMBER(*,0) NOT NULL ENABLE, 
  "NAME" VARCHAR2(45 CHAR), 
  "SQL_INSERT" VARCHAR2(4000 CHAR), 
  "SQL_DELETE" VARCHAR2(4000 CHAR), 
  "CREATED" DATE, 
  "CREATED_BY" VARCHAR2(255), 
  "ROW_VERSION_NUMBER" NUMBER(*,0), 
  "UPDATED" DATE, 
  "UPDATED_BY" VARCHAR2(255), 
   CONSTRAINT "UTBC_TRIGGERS_PK" PRIMARY KEY ("TRIGGER_ID")
  USING INDEX  ENABLE
   )
/

CREATE TABLE  "NPM_TICKLERS" 
   (  "TICKLER_ID" NUMBER NOT NULL ENABLE, 
  "END_DATE" DATE, 
  "DESCRIPTION" VARCHAR2(4000), 
  "AGREEMENT_ID" NUMBER(*,0), 
  "CONTACT_ID" NUMBER(*,0), 
  "DEPARTMENT_ID" NUMBER(*,0), 
  "VENDOR_ID" NUMBER(*,0), 
  "AGREE_APP_ID" NUMBER(*,0), 
  "VISIBILITY_PUBLIC" VARCHAR2(255), 
  "CREATED" DATE, 
  "CREATED_BY" VARCHAR2(255), 
  "ROW_VERSION_NUMBER" NUMBER(*,0), 
  "UPDATED" DATE, 
  "UPDATED_BY" VARCHAR2(255), 
   CONSTRAINT "UTBC_TICKLERS_PK" PRIMARY KEY ("TICKLER_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_TICKLERS" ADD CONSTRAINT "UTBC_APPROVAL_TICKLER" FOREIGN KEY ("AGREE_APP_ID")
    REFERENCES  "NPM_AGREE_APP" ("AGREE_APP_ID") ENABLE
/
ALTER TABLE  "NPM_TICKLERS" ADD CONSTRAINT "UTBC_CONTACT_TICKLER" FOREIGN KEY ("CONTACT_ID")
    REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
ALTER TABLE  "NPM_TICKLERS" ADD CONSTRAINT "UTBC_DEPARTMENT_TICKLER" FOREIGN KEY ("DEPARTMENT_ID")
    REFERENCES  "NPM_DEPARTMENT" ("DEPARTMENT_ID") ENABLE
/
ALTER TABLE  "NPM_TICKLERS" ADD CONSTRAINT "UTBC_TICKLER_CONTRACT" FOREIGN KEY ("AGREEMENT_ID")
    REFERENCES  "NPM_AGREEMENTS" ("AGREEMENT_ID") ENABLE
/
ALTER TABLE  "NPM_TICKLERS" ADD CONSTRAINT "UTBC_VENDOR_TICKLER" FOREIGN KEY ("VENDOR_ID")
    REFERENCES  "NPM_VENDOR" ("VENDOR_ID") ENABLE
/

CREATE TABLE  "NPM_STATE" 
   (  "STATE_ID" NUMBER(*,0) NOT NULL ENABLE, 
  "STATE_NAME" VARCHAR2(50), 
  "CREATED" DATE, 
  "CREATED_BY" VARCHAR2(255), 
  "ROW_VERSION_NUMBER" NUMBER(*,0), 
  "UPDATED" DATE, 
  "UPDATED_BY" VARCHAR2(255), 
   CONSTRAINT "NPM_STATE_PK" PRIMARY KEY ("STATE_ID")
  USING INDEX  ENABLE
   )
/

 CREATE SEQUENCE   "APEX$_WS_SEQ"  MINVALUE 100 MAXVALUE 999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "BUILDING_NPM_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "DEMO_CUST_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "DEMO_ORDER_ITEMS_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 160 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "DEMO_ORD_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "DEMO_PROD_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "DEPT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 50 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "EMP_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 8000 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "LOG_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 380 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_AGREEMENTS_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 420 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_BORDATES_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_AGREE_APP_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_AGREE_TRIG_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_APPROVALS_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_BUILDING_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 140 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_BUILDING_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_CONTACT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 120 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_CONTRACT_NUMBER_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 3202 NOCACHE  ORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_DEPARTMENT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 120 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_DOCUMENT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_EMAIL_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_FLOOR_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 140 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_FORMER_NAME_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 120 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_LOGICAL_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_PHYSICAL_ROOM_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_PHYSICAL_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_PROPERTY_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 660 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_STATE_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_TICKLERS_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_TRIGGERS_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "NPM_VENDOR_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 120 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "PHYS_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 200 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "PROPERTY_NPM_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "S_BUILDING_NPM_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 100 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "S_PROPERTY_NPM_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 120 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "T_P_ROOM_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 220 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "T_B_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 140 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "T_L_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 840 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "T_P_UNIT_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 180 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "S_PROPERTY_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 580 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "S_BUILDING_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 160 CACHE 20 NOORDER  NOCYCLE
/
 CREATE SEQUENCE   "S_FLOOR_SEQ"  MINVALUE 1 MAXVALUE 9999999999999999999999999999 INCREMENT BY 1 START WITH 160 CACHE 20 NOORDER  NOCYCLE
/

CREATE TABLE  "NPM_PROPERTY" 
   (  "PROPERTY_ID" NUMBER(*,0) NOT NULL ENABLE, 
  "PROPERTY_TYPE" VARCHAR2(255), 
  "PURPOSE" VARCHAR2(4000), 
  "START_DATE" DATE, 
  "END_DATE" DATE, 
  "PARENT" NUMBER, 
  "LEASE_TYPE" VARCHAR2(255), 
  "PHY_UNIT_NAME" VARCHAR2(255), 
  "PHY_ROOM_NAME" VARCHAR2(255), 
  "LOG_UNIT_NAME" VARCHAR2(255), 
  "PRICE" NUMBER(*,0), 
  "START_DATE1" DATE, 
  "END_DATE1" DATE, 
  "FLOOR_ID" NUMBER(*,0), 
  "BUILDING_ID" NUMBER(*,0), 
  "AGREEMENT_ID" NUMBER(*,0), 
  "PROPERTY_ID1" NUMBER(*,0), 
  "CREATED" DATE, 
  "CREATED_BY" VARCHAR2(255), 
  "ROW_VERSION_NUMBER" NUMBER(*,0), 
  "UPDATED" DATE, 
  "UPDATED_BY" VARCHAR2(255), 
   CONSTRAINT "UTBC_PROPERTY_PK" PRIMARY KEY ("PROPERTY_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_PROPERTY" ADD CONSTRAINT "AGREE_TO_PROP" FOREIGN KEY ("AGREEMENT_ID")
    REFERENCES  "NPM_AGREEMENTS" ("AGREEMENT_ID") ENABLE
/
ALTER TABLE  "NPM_PROPERTY" ADD CONSTRAINT "B_TO_P_RELATION" FOREIGN KEY ("BUILDING_ID")
    REFERENCES  "NPM_BUILDING" ("BUILDING_ID") ENABLE
/
ALTER TABLE  "NPM_PROPERTY" ADD CONSTRAINT "F_TO_P_RELATION" FOREIGN KEY ("FLOOR_ID")
    REFERENCES  "NPM_FLOOR" ("FLOOR_ID") ENABLE
/
ALTER TABLE  "NPM_PROPERTY" ADD CONSTRAINT "U_TO_R_RELATION" FOREIGN KEY ("PROPERTY_ID1")
    REFERENCES  "NPM_PROPERTY" ("PROPERTY_ID") ENABLE
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_WEBSITE" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
 END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_VISITING_FACULTY" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
 BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(14, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
  END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_SURVEY" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(15, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_SPONSORSHIP" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
 END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_OVER_TWENTY_FIVE" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(4,null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(5, null, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  --insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(19, primary_key_var, 'n', agreement_id_param)
   -- RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(21, primary_key_var, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(20, primary_key_var, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_OVER_ONE_MILL" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  insert_approv_over_twenty_five(agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(2, primary_key_var, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(3, primary_key_var, 'n', agreement_id_param);
  Insert Into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(7, null, 'n', agreement_id_param);
  --INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_OVER_100K" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  insert_approv_over_twenty_five(agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(16,null, 'n', agreement_id_param);
  --INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(4,null, 'n', agreement_id_param);
  --INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(5, null, 'n', agreement_id_param)
--    RETURNING agree_app_id INTO primary_key_var;
  --insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(19, primary_key_var, 'n', agreement_id_param)
  --  RETURNING agree_app_id INTO primary_key_var;
 -- insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(21, primary_key_var, 'n', agreement_id_param)
   -- RETURNING agree_app_id INTO primary_key_var;
 -- insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(20, primary_key_var, 'n', agreement_id_param);
  --INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18,null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_GRANT_RES" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_FOREIGN_PRIV" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(6, null, 'n', agreement_id_param);
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(8, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
 END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_FOREIGN_GOV" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(2, primary_key_var, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(3, primary_key_var, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_COMPUTER_ACCESS" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(13,null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_COLLECT_AGENCY" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
 BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
  END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_COACHES" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(1, null, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(2, primary_key_var, 'n', agreement_id_param)
    RETURNING agree_app_id INTO primary_key_var;
  insert into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(3, primary_key_var, 'n', agreement_id_param);
  Insert Into NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(7, null, 'n', agreement_id_param);
  
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_BCRF" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18,null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_ALCOHOL" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(9,null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
END;
/

CREATE OR REPLACE PROCEDURE  "INSERT_APPROV_5TO25K" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
 BEGIN
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(4, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(100, null, 'n', agreement_id_param);
  INSERT INTO NPM_agree_app (APPROVAL_ID, PARENT, COMPLETE, AGREEMENT_ID) values(18, null, 'n', agreement_id_param);
  END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_WEBSITE" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 1 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_VISITING_FACULTY" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 14 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
 END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_SURVEY" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  delete from NPM_agree_app where APPROVAL_ID = 15 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_SPONSORSHIP" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 1 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
 END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_OVER_TWENTY_FIVE" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 16 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 4 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 5 and AGREEMENT_ID = agreement_id_param;
  --DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 19 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 21 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 20 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
 END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_OVER_ONE_MILL" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 1 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 2 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 3 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 7 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 4 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 5 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 20 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 21 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_OVER_100K" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  delete from NPM_agree_app where approval_id = 16 and agreement_id = agreement_id_param;
  delete from NPM_agree_app where approval_id = 4 and agreement_id = agreement_id_param;
  delete from NPM_agree_app where approval_id = 5 and agreement_id = agreement_id_param;
  --delete from NPM_agree_app where approval_id = 19 and agreement_id = agreement_id_param;
  delete from NPM_agree_app where approval_id = 21 and agreement_id = agreement_id_param;
  delete from NPM_agree_app where approval_id = 20 and agreement_id = agreement_id_param;
  delete from NPM_agree_app where approval_id = 18 and agreement_id = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_GRANT_RES" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  delete from NPM_agree_app where APPROVAL_ID = 1 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_FOREIGN_PRIV" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 1 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_FOREIGN_GOV" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  delete from NPM_agree_app where APPROVAL_ID = 1 AND AGREEMENT_ID = agreement_id_param;
  delete from NPM_agree_app where APPROVAL_ID = 2 AND AGREEMENT_ID = agreement_id_param;
  delete from NPM_agree_app where APPROVAL_ID = 3 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_COMPUTER_ACCESS" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 13 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_COLLECT_AGENCY" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 1 and AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
 END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_COACHES" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 1 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 2 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 3 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 7 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_ALCOHOL" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 9 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PROCEDURE  "DELETE_APPROV_5TO25" 
(
  agreement_id_param NPM_agreements.agreement_id%TYPE
)
AS
  primary_key_var NPM_agree_app.agree_app_id%TYPE;
BEGIN
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 4 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 100 AND AGREEMENT_ID = agreement_id_param;
  DELETE FROM NPM_agree_app WHERE APPROVAL_ID = 18 AND AGREEMENT_ID = agreement_id_param;
END;
/

CREATE OR REPLACE PACKAGE  "SAMPLE_PKG" is
    --
    -- Error Handling function
    --
    function demo_error_handling (
        p_error in apex_error.t_error )
        return apex_error.t_error_result;
    
    --
    -- Tag Cleaner function
    --
    function demo_tags_cleaner (
        p_tags  in varchar2,
        p_case  in varchar2 default 'U') 
        return varchar2;
    
    --
    -- Tag Synchronisation Procedure
    --
    procedure demo_tag_sync (
        p_new_tags          in varchar2,
        p_old_tags          in varchar2,
        p_content_type      in varchar2,
        p_content_id        in number );
end sample_pkg;
/
CREATE OR REPLACE PACKAGE BODY  "SAMPLE_PKG" as
    --
    -- Error Handling function
    --
    function demo_error_handling (
        p_error in apex_error.t_error )
        return apex_error.t_error_result
    is
        l_result          apex_error.t_error_result;
        l_reference_id    number;
        l_constraint_name varchar2(255);
    begin
        l_result := apex_error.init_error_result (
                        p_error => p_error );
        -- If it's an internal error raised by APEX, like an invalid statement or
        -- code which can't be executed, the error text might contain security sensitive
        -- information. To avoid this security problem we can rewrite the error to
        -- a generic error message and log the original error message for further
        -- investigation by the help desk.
        if p_error.is_internal_error then
            -- mask all errors that are not common runtime errors (Access Denied
            -- errors raised by application / page authorization and all errors
            -- regarding session and session state)
            if not p_error.is_common_runtime_error then
                -- log error for example with an autonomous transaction and return
                -- l_reference_id as reference#
                -- l_reference_id := log_error (
                --                       p_error => p_error );
                --
    
                -- Change the message to the generic error message which doesn't expose
                -- any sensitive information.
                l_result.message         := 'An unexpected internal application error has occurred. '||
                                            'Please get in contact with your system administrator and provide '||
                                            'reference# '||to_char(l_reference_id, '999G999G999G990')||
                                            ' for further investigation.';
                l_result.additional_info := null;
            end if;
        else
            -- Always show the error as inline error
            -- Note: If you have created manual tabular forms (using the package
            --       apex_item/htmldb_item in the SQL statement) you should still
            --       use "On error page" on that pages to avoid loosing entered data
            l_result.display_location := case
                                           when l_result.display_location = apex_error.c_on_error_page then apex_error.c_inline_in_notification
                                           else l_result.display_location
                                         end;
    
            -- If it's a constraint violation like
            --
            --   -) ORA-00001: unique constraint violated
            --   -) ORA-02091: transaction rolled back (-> can hide a deferred constraint)
            --   -) ORA-02290: check constraint violated
            --   -) ORA-02291: integrity constraint violated - parent key not found
            --   -) ORA-02292: integrity constraint violated - child record found
            --
            -- we try to get a friendly error message from our constraint lookup configuration.
            -- If we don't find the constraint in our lookup table we fallback to
            -- the original ORA error message.
            if p_error.ora_sqlcode in (-1, -2091, -2290, -2291, -2292) then
                l_constraint_name := apex_error.extract_constraint_name (
                                         p_error => p_error );
                begin
                    select message
                      into l_result.message
                      from demo_constraint_lookup
                     where constraint_name = l_constraint_name;
                exception when no_data_found then null; -- not every constraint has to be in our lookup table
                end;
            end if;
            -- If an ORA error has been raised, for example a raise_application_error(-20xxx, '...')
                -- in a table trigger or in a PL/SQL package called by a process and we
            -- haven't found the error in our lookup table, then we just want to see
            -- the actual error text and not the full error stack with all the ORA error numbers.
            if p_error.ora_sqlcode is not null and l_result.message = p_error.message then
                l_result.message := apex_error.get_first_ora_error_text (
                                        p_error => p_error );
            end if;
            -- If no associated page item/tabular form column has been set, we can use
            -- apex_error.auto_set_associated_item to automatically guess the affected
            -- error field by examine the ORA error for constraint names or column names.
            if l_result.page_item_name is null and l_result.column_alias is null then
                apex_error.auto_set_associated_item (
                    p_error        => p_error,
                    p_error_result => l_result );
            end if;
        end if;
        return l_result;
    end demo_error_handling;
        
    
    ---
    --- Tag Cleaner function
    ---
    function demo_tags_cleaner (
        p_tags  in varchar2,
        p_case  in varchar2 default 'U' ) return varchar2
    is
        type tags is table of varchar2(255) index by varchar2(255);
        l_tags_a        tags;
        l_tag           varchar2(255);
        l_tags          apex_application_global.vc_arr2;
        l_tags_string   varchar2(32767);
        i               integer;
    begin
        l_tags := apex_util.string_to_table(p_tags,',');
        for i in 1..l_tags.count loop
            --remove all whitespace, including tabs, spaces, line feeds and carraige returns with a single space
            l_tag := substr(trim(regexp_replace(l_tags(i),'[[:space:]]{1,}',' ')),1,255);
  
            if l_tag is not null and l_tag != ' ' then
                if p_case = 'U' then
                    l_tag := upper(l_tag);
                elsif p_case = 'L' then
                    l_tag := lower(l_tag);
                end if;
                --add it to the associative array, if it is a duplicate, it will just be replaced
                l_tags_a(l_tag) := l_tag;
            end if;
        end loop;
        l_tag := null;
        l_tag := l_tags_a.first;
        while l_tag is not null loop
            l_tags_string := l_tags_string||l_tag;
            if l_tag != l_tags_a.last then
                l_tags_string := l_tags_string||', ';
            end if;
            l_tag := l_tags_a.next(l_tag);
        end loop;
        return substr(l_tags_string,1,4000);
    end demo_tags_cleaner;
    ---
    --- Tag Synchronisation Procedure
    ---
    procedure demo_tag_sync (
        p_new_tags          in varchar2,
        p_old_tags          in varchar2,
        p_content_type      in varchar2,
        p_content_id        in number )
    as
        type tags is table of varchar2(255) index by varchar2(255);
        l_new_tags_a    tags;
        l_old_tags_a    tags;
        l_new_tags      apex_application_global.vc_arr2;
        l_old_tags      apex_application_global.vc_arr2;
        l_merge_tags    apex_application_global.vc_arr2;
        l_dummy_tag     varchar2(255);
        i               integer;
    begin
        l_old_tags := apex_util.string_to_table(p_old_tags,', ');
        l_new_tags := apex_util.string_to_table(p_new_tags,', ');
        if l_old_tags.count > 0 then --do inserts and deletes
            --build the associative arrays
            for i in 1..l_old_tags.count loop
                l_old_tags_a(l_old_tags(i)) := l_old_tags(i);
            end loop;
            for i in 1..l_new_tags.count loop
                l_new_tags_a(l_new_tags(i)) := l_new_tags(i);
            end loop;
            --do the inserts
            for i in 1..l_new_tags.count loop
                begin
                    l_dummy_tag := l_old_tags_a(l_new_tags(i));
                exception when no_data_found then
                    insert into demo_tags (tag, content_id, content_type )
                        values (l_new_tags(i), p_content_id, p_content_type );
                    l_merge_tags(l_merge_tags.count + 1) := l_new_tags(i);
                end;
            end loop;
            --do the deletes
            for i in 1..l_old_tags.count loop
                begin
                    l_dummy_tag := l_new_tags_a(l_old_tags(i));
                exception when no_data_found then
                    delete from demo_tags where content_id = p_content_id and tag = l_old_tags(i);
                    l_merge_tags(l_merge_tags.count + 1) := l_old_tags(i);
                end;
            end loop;
        else --just do inserts
            for i in 1..l_new_tags.count loop
                insert into demo_tags (tag, content_id, content_type )
                    values (l_new_tags(i), p_content_id, p_content_type );
                l_merge_tags(l_merge_tags.count + 1) := l_new_tags(i);
            end loop;
        end if;
        for i in 1..l_merge_tags.count loop
            merge into demo_tags_type_sum s
            using (select count(*) tag_count
                     from demo_tags
                    where tag = l_merge_tags(i) and content_type = p_content_type ) t
               on (s.tag = l_merge_tags(i) and s.content_type = p_content_type )
             when not matched then insert (tag, content_type, tag_count)
                                   values (l_merge_tags(i), p_content_type, t.tag_count)
             when matched then update set s.tag_count = t.tag_count;
            merge into demo_tags_sum s
            using (select sum(tag_count) tag_count
                     from demo_tags_type_sum
                    where tag = l_merge_tags(i) ) t
               on (s.tag = l_merge_tags(i) )
             when not matched then insert (tag, tag_count)
                                   values (l_merge_tags(i), t.tag_count)
             when matched then update set s.tag_count = t.tag_count;
        end loop;
    end demo_tag_sync;
end sample_pkg;
/

CREATE OR REPLACE PACKAGE  "SAMPLE_DATA_PKG" as
  function varchar2_to_blob(p_varchar2_tab in dbms_sql.varchar2_table) return blob;
  procedure delete_data;
  procedure insert_data;
end sample_data_pkg;
/
CREATE OR REPLACE PACKAGE BODY  "SAMPLE_DATA_PKG" as
function varchar2_to_blob(p_varchar2_tab in dbms_sql.varchar2_table)
    return blob
is
  l_blob blob;
  l_raw  raw(500);
  l_size number;
begin
  dbms_lob.createtemporary(l_blob, true, dbms_lob.session);
  for i in 1 .. p_varchar2_tab.count loop
    l_size := length(p_varchar2_tab(i)) / 2;
    dbms_lob.writeappend(l_blob, l_size, hextoraw(p_varchar2_tab(i)));
  end loop;
  return l_blob;
exception
  when others then
    dbms_lob.close(l_blob);
end varchar2_to_blob;  
procedure delete_data is
begin
  delete demo_product_info where product_id <= 10;
  delete demo_customers where customer_id <= 10;
  delete demo_states;
  delete demo_constraint_lookup where constraint_name in ('DEMO_CUST_CREDIT_LIMIT_MAX','DEMO_CUSTOMERS_UK','DEMO_PRODUCT_INFO_UK','DEMO_ORDER_ITEMS_UK');
end delete_data;
procedure insert_data is
  i           dbms_sql.varchar2_table;
  j           dbms_sql.varchar2_table default wwv_flow_api.empty_varchar2_table;
  l_blob      blob;
begin
  -- Table: DEMO_PRODUCT_INFO - Product 1
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB00840009060610100F120D12140F130F1210171510141410100F1410101410151614101414171B261E1719231912121F2F2023282C2C2C2C151F31353C2A35262B2C2901090A0A0D0A0D190C0E1A';
  i(2)  := '291E1C1829352929292934292C29292934302C3435292929292C3229292C2E30292C2A2929292929292A34342929292A362934293229FFC00011080068006803012200021101031101FFC4001B0000020301010100000000000000000000000502030401';
  i(3)  := '0706FFC400381000020102030406060A0300000000000000010203110412210531415161718191B1D113162252A1C10632627292A2B2E1F0F1144253FFC40014010100000000000000000000000000000000FFC400141101000000000000000000000000';
  i(4)  := '00000000FFDA000C03010002110311003F00F71000000038DD80CD8DDA54E8FD7767C12D5BEC17FAD14F8467F0425C52752ACE6EEEF2D38E9C2DD962FA7B39DAFBBAD80D7D6487B92EF45B4B6FD27BD4A3D6AFE026A5826DB5C8B6585CBBD3F15F003E96';
  i(5)  := '9D55259934D3E28909F62D55193A775AACCB5E4D2D3BFE0380000000000000000306D1C7BA6D452576AF77C3B05D3AB29272936F46D747616ED377AAD72497CFE6432E8D74018B0352DEC9B65BB4304A8B8BB9BE35565CCDA4B9B028A2E4E4D6693CBBD7';
  i(6)  := 'A3CA9DD70935AF6335CEAA8ACCC850C5427B9AEADCFAEDBCCB8F9DD018A9576EBA9BD13BAB2E09AD3E23AA1899C773D393D50A30D45B9C5F292F11C4D00D30D5B3C54B7735C9A2D316CD96928F4DFBFF00A368000000000009314AF526FED782488C5D8E';
  i(7)  := 'D4FAD2FBCFC59D4C0C98DC5C29ABCB7BDD15AB9752153C0E2312D395E953E09DD59756F6FA47F0A714DB495DEF7C7BC9E6E2025AFF0047249274E6EEB726EDF14729CEB474AD09597FB2D7BEDBC76AA0019B096D24ACD741A991549277B24FA34BF5F326';
  i(8)  := 'C0BF02ED3EB88C05D4349C7AFC50C4000000000004553EB4BEF3FD4C89D9BF6A4BED3FD4CED80132C488E43B18D80924EFC2D6D02DA9240076C409391C881645D9A7C9AF1198AA5B86917749F34074000008CE564DBDC95DF612336D0A96A72E9D3BC04C';
  i(9)  := '9712CBD8AA555477FF003F972553556E7A77BB0175395D26F7D89A2BB924C0929ABDB4BF207239955EFC4E30244A2884592B81218619DE11EAF016A66FC14BD8EA6FC6FF003034000000BF6C26E31D6DED6EB2D74180AB6CD4D631E86FBFFA0174AF75C5';
  i(10) := '5F57A69F02CBF1E9F995FA65C5A5DA5753190D1668DDB56575CC0D8892650EB1CFF200D2A471B323C747364E3FB5CB3D381A1324999957458AA202D36ECE96925D37EF5FB0BB31B366CBDA6B9AF07FB80C40000059B536142BC94DB926959DB5BAE1D0B8';
  i(11) := '80018BD49C33DF9DF6C57C8ED3FA13858C9497A44D3BA7996FEE000362D814FDEABF89791C7F47E973A9F897900010F56695F366AB7FBCBC89FABD4FDEABF8A3E47000EFABF0F7EA77C7C816C08FBF53F2F9000125B157FD2A7E5F22DC2ECEC92CD9E4F4';
  i(12) := 'DCD25E00006D00003FFFD9';
  l_blob := varchar2_to_blob(i);   
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(1, 'Business Shirt', 'Wrinkle-free cotton business shirt', 'Mens', 'Y', 50, l_blob,'image/jpeg','shirt.jpg',systimestamp,'Top seller');
  -- Table: DEMO_PRODUCT_INFO - Product 2
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB004300090607080706090807080A0A090B0D160F0D0C0C0D1B14151016201D2222201D1F1F2428342C242631271F1F2D3D2D3135373A3A3A232B3F443F384334393A37FFDB0043010A0A0A0D0C0D';
  i(2)  := '1A0F0F1A37251F253737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737FFC00011080068006803012200021101031101FFC4001C00010100020301010000000000000000000007';
  i(3)  := '01050406080203FFC4003D1000010303000507080807000000000000010002030405110607122141132231516171A123328191B1B2C1D11415174273A2C2E1083552626392F0FFC400160101010100000000000000000000000000000102FFC400161101';
  i(4)  := '010100000000000000000000000000000131FFDA000C03010002110311003F00B822220CAC2220D36995DA6B168B5CEE94DC919A969DD2462504B4BB8038238A81FDABE9954641B9450FE15247F1055135FF00719A9F4628A82225ACADAA025238B58368';
  i(5)  := '0FF6D9F528640730B2403EF7387664FCD54AED726B0F4B651CFD20ABC7F8E28DBEC62F96699E9387B2575EAE2F0241CD339009E9C1031B968E2635B308F1B8B3687FDE80BF6899B54F82778760F7E4223D4764B9C379B4D2DC69811154461E03BA47583D';
  i(6)  := 'C7217394E75275D24D63ADA17BB69B4B51B51E4EF0D78CE3D60FAD519468E288880888832B088832B0888239FC424DB42CB4CDE91CAC9E2C1F351DA3CF9685E31839C761562D7DC61D5D65706E5DC94C0F7658A3F2F92AB8DFD01C0B4FB5547323396C2F';
  i(7)  := 'FBCD3B2572E2DCF76EDC4839EA2B894FE71683CD3BD72C1C222A1A8E90FD3EF118E83144EF5177CD57148F519138D65E26079A2389847692E3F055C5161C5111144444044441958444126D7B47E52C737E3B3DC2A3978E646D9319C387B55B35EACCDBAC';
  i(8)  := 'F2637B6A9EDCF7B3F6516BC0CD13B72ACD628DD9D82B9A3A16AE85FE4D87B96CDDB813D43A0A0ADEA24E692F3BBA278C7E52AA6A5DA88C1B65DDE38D4B3DC55151A87144440444419584441958444130D7A39FF565A1A3CC354F27BC3377C546AB5BB701';
  i(9)  := '6F5E7D8AD3AF28F6ACD6C7EEE6D59DD9FEC2A31543C91559BAD4D01CD3E388385B57CC1A59B5E6BDBD5C56A2DC41E51B9FBCB6407290341192C38282CFA85FE4F750785537DC0AA2A57A8527EADBBB0F0A867BBFB2AA28D1C511101111011110111104E3';
  i(10) := '5DF1ED582DF2648D9ACC77E58EF928A551E663AD5AB5E240D1FB70E3F4E1EE3944EA5D81E8552EB596EA771A7AA9D993C94CC616F0E7079CFE55B2A576D31E47A5A46F053472865ABB1E90CF1F4518A79DDDA36DCD3E0E27D0BE58ED97646F0E6EF088B0';
  i(11) := '6A19F982F6D3B9DCAC2EC7616BBE4AAEA23A89AA2DD23B8D2ED1C4B461E476B1E07EB2ADCA35044E28808888088880888826FAF16E6C16E775568F71CA1F5AE3E66CEF20E30AE5AF1648746289EC692195AD2E3D5CC763C5445A4020CCE193D00AA9544D';
  i(12) := '5058C4FA15A5B34806DD631D4C3233B21B1923C5FE0A774F87C63686F6F4772B16A29CDAAD19BCC61C365D5EE6EEE039360524A8A47DBEE1514736E929DEE89DDED38F820EE1A9D70834F2368CE65A595BEC77E957D5E78D5538FDA1DBC0DFCD941EEE4D';
  i(13) := 'CBD0EA1044E288A222202222022220D6692D961D21B1D55AAA5EE8E3A86805ED0096E0820EFED0BA041A94B609335177AD7B3FA636319E3BD110774D12D11B5E89524F4F6A13113C9CA4AF9A4DA738E303A87829A6976ADB48AB748AB6BA823A49A0A99D';
  i(14) := 'F2B713ECB9A09CE08701E194441D87579AB67D86E02F177A80FAE667918A17E591ED3483B471CE3BFB876AA422202222022220FFD9';
  l_blob := varchar2_to_blob(i);
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(2, 'Trousers', 'Black trousers suitable for every business man', 'Mens', 'Y', 80, l_blob,'image/jpeg','pants.jpg',systimestamp,'Top seller');
  -- Table: DEMO_PRODUCT_INFO - Product 3
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB00840009060614120D1513131413131216141319111815111015121917131016191C151714181B281E23192F1F18141F302025332C2E2C2C151E3135312A35262B2D2B01090A0A0505050D05050D';
  i(2)  := '291812182929292929292929292929292929292929292929292929292929292929292929292929292929292929292929292929292929FFC00011080068006803012200021101031101FFC4001C0001000203010101000000000000000000000708030406';
  i(3)  := '050201FFC400351000010401010505060505010000000000010002031104210506071261223151819113144171A1C123324392B142647293A233FFC40014010100000000000000000000000000000000FFC4001411010000000000000000000000000000';
  i(4)  := '0000FFDA000C03010002110311003F009C511101111011110112D1011110111101111011110111783BF596E8B6564BD8E2C7888F2B81A20920687C7541A5BC9C4AC4C371612E9651A164601A3E0E71340F4D4F4514EF8F1632725CCF60E7E2B1A6F96391';
  i(5)  := 'DCCEB03F3BC575D171D24C4AD3BB76A83AB3BFF9FC95EF330EFD7DAB89A23AEB6BDFDC8E2BC98D23D99B24D910BAB90E8F9186CDEAE365BD2FE4A3FBD3C96A4F26B682D26EFEF9E266FF00E1287380B2C702C900F1E576A4751617B6AA7ECCCF7C523648';
  i(6)  := 'DC58F69B6B9A688215A6D959264C68A4356F8E371AEEB730135EA8369111011110111101729C5198376264DE96D601D4BA660A5D5A8DB8E79FCBB3E28EF592606BC446C77D2DCCFA2083DC7BD602F5FBA97BA8121ADED1AD06A059F335E6B137BD0666CD';
  i(7)  := 'A57A2C6C1657E35A49F8681656328A0CC0D05677727239F64E23BBEF1E2FF98C0FB2AB934BDB68E97EA558AE10ED0126C689A3BE27491BBE7CE5E2BA53DA83B4444404444044440506F1CB69876D08E30EE61143AB41069D23C937D794314E45560DFBC8';
  i(8)  := 'F69B5B2DE5BFAF2015A68C7726BFB50696CBC6BC0CD97E03DD1BD2DF90E35E8C5E3C2755D5ECF84B777326420812E763B584F71F6513DC6BE56E5CB3020C910EF3D7EC17D386ABE623A1F9EBE817EFB3B283676B6CCE4871721BF9656CCC759FD482675E';
  i(9)  := '9E1C8F8BEAA46E06EDD7372DF8C4FE1CAC2F68B341F1D6A0756DDFF88F05C7E4623A4D881C0170C6CCED559A66542059F06F3C4DF37AD8E1965166D9C53757272FEF639B5F541659111011110111100AABFBE7D9DAB983FB99FEB2B8FDD5A05136D5E104';
  i(10) := 'F93B4B22674B1450C92B9CDA0E7C946BFA680BF341CE6F8B9B1EEE6CA89BA07B1F2B878B8B4127D6477AA8EED485C5E8C43362E1B5C5CCC7C46004D5DB9CE166B4BA635472F7A0FA8C9D7E67ECB235DAAD780F67CCFF000164E641DBEE8D3F62ED66135F';
  i(11) := '818EF1F1D6395EEFE43479AF1772EC6D3C4D35F79C7AFF007B175BC0DC664B939714AD6BE37E3B439AE16D2D12EB63CD762383D1C5B460C9C690B6264CC7BE292DD41A6FF0DFDFDE068EF54123A22202222022220222208B7899C2D9B3324E563BDAE716';
  i(12) := '35AF8DE794F60502C777791AF9EAA28DA9B859F09224C49FE6D8CC8DFDD1D856A51055B878759DEE2FCA38F20635CD1CA58E1316906E411D73728ECEBD6FB812B1ECEDC7CE9B56624E47898CB1BEAFA0AD42208B3847C3DCAC2C8972324363E78BD9B181';
  i(13) := 'E1CFD5ED7173B97B23F2D55FC7E0A534440444404444044440444404444044440444404444044441FFD9';
  l_blob := varchar2_to_blob(i);
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(3, 'Jacket', 'Fully lined jacket which is both professional and extremely comfortable to wear', 'Mens', 'Y', 150, l_blob,'image/jpeg','jacket.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 4
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB0084000906061010101512131215141316151214171614181A1417171719161815181C1A121720261F172525191713212F202428292C2D2C171E3135302A3529372C2901090A0A0E0C0E190F0F1A';
  i(2)  := '2C241E222D2A2D2F2C3535352C352E2D2F2934292929352B2A2B3535352A2C29292C2A342D2C29342C2D2C2C2C2C292C2C342C2C352CFFC00011080068006803012200021101031101FFC4001C0001000203000300000000000000000000000607030405';
  i(3)  := '010208FFC4003710000103020304060806030000000000000100021103041221310741517105061361A1C122233242728191B11492A2A3B2D1526282FFC4001A010100020301000000000000000000000000030602040501FFC400271100020202020003';
  i(4)  := '090000000000000000000102030411051221314113224251618191E1F0FFDA000C03010002110311003F00BC5111004444011141FAC1B55B6B5B936EDA6EAA5BED39AE01A1D3184647111067E8BCDE892BAA76BD416C9C22AEAA6D928013F877FE613E22';
  i(5)  := '254CBA03AC142F688AD45D2D3A83939A6261CDDC5134CCEDC6B6A5B9C7474D1117A40111100444401111005C3E9DEB8DA599C351E4BE27031A5EE83A4C64D983A90BB657CFDD2DD2A6ADCD4AC7DAA952A3A383412D689F85AD1F258C9E8DEC1C659136A4';
  i(6)  := 'FC1124EB46D66E1CC70A34FB1A64118DDE95523491193350273EE2A056142BBDA5CF034903780738E3BF7AE81AA5D2665A72EF1CD65B7799D00CA26758EE50B932D3461D54BF70E50E44F70D4ACDD03D64BCB0AC1C3D597000080585B3935EDEEDC7519F';
  i(7)  := '195BF6B4435F53862007289F3F058AF28626E1DE41FAEE45226BA88DB1D48B2BA2F6B54B26DCD1753397A74FD630EE397B4DCFE2E6A776B74CAAC6D4638398E01CD70D082A84B6A62A31BC3D1EF22449F35676CDAEBD53E8C9863839B3B83B51F513FF00';
  i(8)  := '4B38CF6F4CE0721C742A83B6BFC133444529C108888022220305FDD0A549F50890C63DF1C7082EF25F33BEB132749CE3C4F8AFA33ACD6B56AD9D7A5440351F49EC6C9812E1875E44AA3BA5FA917F6F4DCE7DB54710DD698ED47EDCC6BC372C2475F8D946';
  i(9)  := '3DB6F4CF4A00B9808C21AE683DFDFE2BDC320653C6777D1712C6EF0B58D20E33220FBB2E20E474D4A945D570D69F467700B5DAD168AAC528ED1A93C0CCC67A2C8FA1886872D0C792F177488C21870983A18CF285B02BBC522E3ED0827CD784DB39D60C75';
  i(10) := '3AC448C265E3B88D72E4E2A7BB3CBD06EC86990EA6F197169698F979AAE9B56E2E6E0368D17D47B2A104526927B39D491ECE8333C558DD5DEA5DF50BBA35C06D3A6D3EB18F7CB9C1C0830D6820113C46614B18BDA672B3AFAFD8CE0DADFC8B291114E53C';
  i(11) := '222200888802222028DDA7D916F4D623A3E95178F94B3EED586A36699E454C76B960C9B6AF3E98754A51C5A407EBDC5BFACA81DDDC3832018DC56BD9E65BF8B96F1D337A98070F2FE97B5564D3A83FD4FF006B0503EC99990392DCA6062238823C14475B';
  i(12) := 'D0E9EC72CCFE32F2A6EECEDC7CDF2E3FC55B4141F6516EC6DBD53EF9AB0EE4D680DFBB94E56DC7C8A3E7BDE44C2222C8D208888022220088BC140553B55E95C7774E8839526623F13E0F835ADFCCA1784B839DBA16CF58EEFB6BCB8A9C6AD48F85AE2C1F';
  i(13) := 'A405AF484D277082B5E4FC4B9E157D298C7E86D3D863271D32E208EF596C6F7161275DEB568BE1E1A4983946FDDC744AB43B27EB91321466FEFD49FECE2F705C56A07DF870E627C89FA2B182A8FABF5B0DD51AA379603C89C3F6255B816C56F68AAF2F57';
  i(14) := '4BFB2F897E8222290E38444401111005E095E57822501F383BD22493AB9C4FCCCAF5AD5096963781FB2B96E7661D1EF74863E9F731E437E4D7481C864B09D93F479D7B523876900F380A1E8CB24394A5475A65436D544B49DD9C9D4F32BB97943188CB16';
  i(15) := 'A2558CCD96F470F71F1FE38CC7DA7C56C376756000182A40F67D63FD1E466578EB6C9A3CC511F069FF007DCAEFA1AA10583396BDBFC82BA82E359F53ACE910452920C82F739F9F18263C17682CE11EA72391CC8654A2E09AD0444521CC08888022220088';
  i(16) := '8802222008888022220088880222203FFFD9';
  l_blob := varchar2_to_blob(i);      
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(4, 'Blouse', 'Silk blouse ideal for all business women', 'Womens', 'Y', 60, l_blob,'image/jpeg','blouse.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 5
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB004300090607080706090807080A0A090B0D160F0D0C0C0D1B14151016201D2222201D1F1F2428342C242631271F1F2D3D2D3135373A3A3A232B3F443F384334393A37FFDB0043010A0A0A0D0C0D';
  i(2)  := '1A0F0F1A37251F253737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737FFC00011080068006803012200021101031101FFC4001C00000104030100000000000000000000000002';
  i(3)  := '03070801040506FFC4003C100001030203020A0803090000000000000100020304110506210731121314617182A1B1C1C222324151728191D2335292424554738394A2B2D1FFC40014010100000000000000000000000000000000FFC400141101000000';
  i(4)  := '00000000000000000000000000FFDA000C03010002110311003F009C508420179BC633B60D83626FC3EBE49992B1AD7173622E68B8B8DDAF62F48ABBED0AB5D579BB1491AE04366318E8600DF04131479FB2C49FBD58CF8E37B7BDAB6E3CDD9724F571BA';
  i(5)  := '0EB4ED1DEAB63A57FB7BD20CEFE7FAA0B3273565E1BF1CC3BFB967FD4D3F38E5B60BBB1CA03F0CC0F72AD3CA1C3DFF00558E3DF6B0EF4162E6DA1656886B8AB5FF00CB89EEEE6A5E0F9EB03C67128B0FA09667CD28716F0A12D1A024EA7982AE8C91C5BA';
  i(6)  := '903E6BB993AB8D0E67C2EA4BF82D654B0388FCA4F04F61282CAA10840210840210840DD44AD8209267FAB1B4B8F40175576BA674F5124CF37748E2F71E726E558CCE953C932A62B28363C99ED1D2E1C11DEAB74C7D22835DE9052DC9B28125BEE40D12BD';
  i(7)  := '8B0832D3AAD984906ED363EC3CEB5427E2DE82D2E0F58310C268AB01BF1F0324FAB415B8BC9ECB6AF9564AA104DDD097C27AAE36EC217AC40210840210841E3B6AF51C464E9D80DB8E963676F0BCAA0294EAA69DB55470306A082FF89505FF00A5A47994';
  i(8)  := '2B26F40D9DE9B725949720C0DCB077AC8DC90E3AA0504F446C994E30A09BB62753C66055D4C4EB1557087439A3C5A548CA21D86D4DABB14A527D7863900F8491E60A5E40210840210841126DB6A2F5B86D37E485EF3D62079545321520ED86A38DCD463B';
  i(9)  := 'FE153C6DEF779947B2A045D61601438A049364D9372B2F49BA07014E34EA99BA5B5C8241D8ED518338C71DF49E9E48FB03BCAA7855B367F55C97386132DEC0D43584F33BD1F32B2680421080421082BDED2AA394670C4DD7D1B2060EAB40F05E4252BB59';
  i(10) := 'AAA795660C4A606E1F552B874708AE1C9B90360A1C74491BD04E8812E29008BACBB7240DE81C26C02530A6DC74012A3D107470D9CD3564150D363148D907C883E0AD5B1C1EC6BDA6E1C2E3A154C8BD603DEAD0E57A8E5796F0BA8BDCC949113D3C11741D';
  i(11) := '44210804D554A20A696676E8D85E7E42E9D5C7CDF3F27CAD8B4B7B114920079CB48F1415B2A1C6491CF76F71B95AB22DE923209D345AAE8CD906B5B5582344F18CAC7166DA20D770D124356C188958E28A060EAEE64B60D53BC494A1111B9011FAC158CD';
  i(12) := '9854728C91869BDCC6D7C67AAF70EEB2AEEC88837B153BEC6DE5D949EC274655C807410D3E283DDA1084024C91B2563992B1AF63858B5C2E0FC90841C2C4325E5DC42E67C2A06B8FED420C47FC6CB8D36CB32E48EBB456463DCD9EE3B41421032ED9365E';
  i(13) := '3BA7C407F559F6A6CEC8F02FE3310FD71FD8842049D90E097D2BF10FAC7F6A50D91E0237D66207AF1FD8842075BB27CBA37CB5EEE999BE0D5B94FB33CAF08F4E8E698FBE4A87F8108420E952E4BCB74AE0E8B06A4E10D417B387FED75DD631B1B0323686';
  i(14) := 'B4681AD16010840A421083FFD9';
  l_blob := varchar2_to_blob(i);   
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(5, 'Skirt', 'Wrinkle free skirt', 'Womens', 'Y', 80,l_blob,'image/jpeg','skirt.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 6
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB0084000906061410101214121216151516141614181713141A1816141C141815151516151B1C1C26212320231F1E131F2F2C2F27292C2C2F161F3135303635282D2C2A01090A0A0505050D05050D';
  i(2)  := '291812182929292929292929292929292929292929292929292929292929292929292929292929292929292929292929292929292929FFC00011080068006803012200021101031101FFC4001C0001000202030100000000000000000000000607050801';
  i(3)  := '030402FFC4003D10000103020207040607090100000000000100020304110521060712314151712261819113233242A1B1145262C1D2E1F0243344547282B2C2D143FFC40014010100000000000000000000000000000000FFC400141101000000000000';
  i(4)  := '00000000000000000000FFDA000C03010002110311003F00BC51110111101111011110111101111011110140F583A78EA3F57016FA40369C5C2E1BC436DCF8F9298E295ED82192476E6349EBC8789B0F15AF98BE206A2491CF372F2E24F3BE6505ABA05A';
  i(5)  := 'CA662168A4D964F6BD87B3201BF66FB9C3336CF2CC1DF69C02B50A96B1D04B76B8B5CC75C106C4169B823C6C56C46ADF4FDB88C5B32102A236F6DA32DB1BBD2307CC7027910826C8888088880888808888088882BFD6D62A590C7103ED12F7746E4D1E64';
  i(6)  := '9FED54CBA5ED2B335BAEF5EDEE89B6F372AB2475B3418CC5E2ED0773C8F51F97C9756178D4B49511CD0BCB5EC21C08F88238822E08E457BE46FA46969F0EE3C160DF11B9B8B20DAED04D358F14A612B2CD7B6CD963BE71BBF09DE0FDE0A922D4AD0ED289';
  i(7)  := '70DA96CF11B8DCF65FB32378B4FCC1E0405B47A3F8F455B4F1CF0BB698F1C77B48F69AE1C083914192444404444044440444410ED6268D7D2610F68ED301BF7B7F254562942F89C438640FEAEB691CCB8B1556E99E0F1898B0D838E6D07DE0791E07AE5D';
  i(8)  := '37A0A4A69B657B288B26F686FC89E20F023F5CD7AF1EC00B412D19663A11BC77151FC2EB0C3280ECC6E2398E36F9F820CA55612633CC70206F521D5D69BBF0AA8B3EE69E42048DFABC048D1CC7C465CADDEEA5CAD7BB1D623967B9C147714A32D26F641B';
  i(9)  := '554954D958D7B1C1CD700E6B9A6E1C08B820AEE5436A9358BF4478A4A97FA97BBD5B9C7289C7813F549F239EEBABE1A5072888808888088880AB8D679D99E99DD07992D3F3563AADF5B86C694FDAFF0076A0C1CBA28F9E9E69E21B45993E203F78DB5DC5';
  i(10) := '9F6DB911CF31C55618BE12369AF6EEC9C08DC415B1FA0B1FECA4F391C7C834281EB2F43442E74D10F5523892D0328DE45DC07D97E67B883CC208668A5689186171CDA2EDBF2E5E17F885D7A47426DB43DDDFD387928E42F7472ED372734DC594D61C4595';
  i(11) := '515F739B9381E1CC1EA82BD94E7FAC95C1AA8D6B36CCA3AB7804766295C72EE63CFC8F0DDD2B0D20C3FD11ECFB27E1DC5606F641BA60AE56B7686EB9AAA89A23947D2221900F367B4726BB9771BABB343B4F69F138F6A2DA63AF62C900072B5F64836210';
  i(12) := '4951110111101569AE007F67205C037F27372BEEE0ACB5F2F8C11622FD73411DD01976A8C1D923B6EB6D0B5F71B8EECFE0B2D8D6182A6092277BED201FAA77B5C3A1B1F05ED01728356B48680C1507686C9CC11C9CD243879DFC9634BDF1BB6E3716B871';
  i(13) := '1C7B8F30AE1D6A68697174EC1D9766E23DC70CB68F7385BC41E6AAA9E89C066DBF7B730507C9C484E3B6D0D76E3B2323D415D35182C4FCC12C3F6736F913971E2B0F575258E22C4750BE63C71C3864833B4B81C6CB5C17FF0051ECF90FFAA59875596869';
  i(14) := '63B64B7D92DCB67A5940E2D261EF34AC8D2E95C4398EA105E1A3BAC4C832A8777A41C7AA9D53D4B6468731C1C0EE2372D68A7D2F86D62F1E2A41A3FAC2FA3BEF14991DED26ED77820BF1160F4634AE2AF66D466CE1ED32F9B7BC73088338888808888387';
  i(15) := '36EB0788683514F732534773C58360F9B6C88823188EA4A924BFA392688F2DA6C8DF27B49F8A8F566A1A41FBAAA89DDD2425BF16B8FC9110626A35215A3DDA67F491C3FC98BC6ED4A56FF2D1F84CCFC972883ACEA3EACFF0C3C2767E25CB3515567FF168';
  i(16) := 'EB3B7EE251104FF56BAB0930C99D2C92373616FA3639CE19DB371361E43C511107FFD9';
  l_blob := varchar2_to_blob(i);    
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(6, 'Ladies Shoes', 'Low heel and cushioned interior for comfort and style in simple yet elegant shoes', 'Womens', 'Y', 120, l_blob,'image/jpeg','heels.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 7
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB004300090607080706090807080A0A090B0D160F0D0C0C0D1B14151016201D2222201D1F1F2428342C242631271F1F2D3D2D3135373A3A3A232B3F443F384334393A37FFDB0043010A0A0A0D0C0D';
  i(2)  := '1A0F0F1A37251F253737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737FFC00011080068006803012200021101031101FFC4001C00010002030101010000000000000000000005';
  i(3)  := '07040608020301FFC400381000010303020404050204060300000000010203040005110621123141510713617114224281913252152362A12453637282D1A2B1F0FFC4001501010100000000000000000000000000000001FFC400141101000000000000';
  i(4)  := '00000000000000000000FFDA000C03010002110311003F00BC694A502A3EF979816280B9B749096194EC33B951EC91CC9F4159921E6E3B0E3CF2C21B6D254B52B92401924D7366B5D452F545E152DDE311C12988C7F968276DBF72B627D76E82836CD43E';
  i(5)  := '30CF7D6A6EC515B8AD720EBE02DC3EB8FD23FF002AD51EF10F55B8E719BDC849CE7094A123F01352965F0C6E72A22A7DF64B3658294F1295277584F729C809FF009107D2A22F0CE8C8414CDB9DBC5CDD1B79C5C6E3B5EE3282A3F81EF41296AF15F53C25';
  i(6)  := 'A7E2643139B1CD2FB4013FF2460FE73568E8EF11ED3A95C44573306E0AE4C3AAC870FF0042BAFB1C1F4AE715A92164A028273B027247DF033F8AF685F25209041C820E08A0EBFA5555A07C5186AB6B70F54CA2D4969410996B4929713D0AC8E479824EC7';
  i(7)  := '19CE4D5A2C3ED48650F47710EB4B1C485A1414950EE08E741F4A52940A52940A52941A9F8A52171F43DC036A292F16D824765B894ABFB13505E186908ED369BFCF682DF7093112A1B348E5C7EE7A1E83DEA7BC52643FA12EA8512308429247421C491FDC';
  i(8)  := '57AD03A921DF74D32EB45B6DE88D25A92C0DBCB2918C81FB48191F8E60D055DE31EA67AE77D72CEC2CA6040504AD20ECE3D8C927FDB9007AE4F6AD023449535DF2A1C77A439FB196D4B57E003562F87F62B56B2D557E9376794EF95294FA2303C21D4AD4';
  i(9)  := '77279E0600C0EE3DAAEC83062DBE3A63C18CCC7653FA5B6501091F6141CCADE84D54F27891609D8FEA4041FC2883587334CDFADC92B99669ECA0735AA3AB847DC0C5756E053141C8C405455BA9C6C7814074CEE3FF005531A335A5D348CC4AA2AD4F4052';
  i(10) := 'B2F425ABE457729FDAAF51F7CD6F5E369B6AAEB6D851E2B0998E381729E6D094AD4951C2524F5E4A3BF2DBBD6ADAE7C3D9FA55DF3D2AF8BB6AD5C289094E0A09E4163A1EC46C7D0ED41D0563BB44BE5AA3DCADEE7991DF4712491823A1047420E411DC56';
  i(11) := '7D541E05CF71A7A7DA1649696D894D8FDA73C0AFCFC9F8AB7E814A52814A528237525B05E6C53ADDC5C26432A42547E957D27F38AE6885367D8AE725A0A7A2C81C6C3C1270A4F45248E447A1EC08E86BAA6B41F113C3C6751955CADA50C5D529C2B8B644';
  i(12) := '8039057657657D8F42029AD33709BA5EFF001AF36FFF0012D20F0BCDA0E0B8D1C71248E9D083DC0AE97B55CA25DADECCE80F25D8EF24292A1EBD08E87B8E95CBF3A14BB5CD7624D65C8F259570AD0AD8A4F3E9E841C8EF5F045DA75B9F0F4194F4774F35';
  i(13) := 'B2B2851F729C6683ACEA27545FE1E9BB3BD719CA1C28D9B6F382E2CF248FFBE8013D2B9FE1789FAB22A0245D14E8FF0059A42CFE48CFF7AC0D45AAE6EA87D976F8E38EF929E16DB688420773C38E67A9F4141F37E64CD51AB6338F28A9E992D0949DC6EA';
  i(14) := '524647618C63B003B57466ADBB592DD6A7DABF38DA997DB524C6FD4B781E894F3FBF21DC5739C290CC490DCA88D3A87DB3C4DBA5F21493DC70E2BD4B96F3E56E38AF995BA959DD5EE4EE7EF41657821143970BC5C30A094A1B6194A8E4A504A95BFAEC33';
  i(15) := '56ED695E13D8E459B4D71CC6CB4FCC73CE2DA861484E004823BEC4E3A66B75A05294A05294A05294A0ABBC66D28A99153A82DE83E7C64F0CB4A47EB687257BA77FB1F4AA8176DF8948217C0A1CF6C8AEAF5A429252A00823041EB5CEBA8D36987A9E6C1B';
  i(16) := '3B9C7110E14B791F2A55F52127A849D81F4237C6486A122D3263E0E50B4138E249D87BE6BE8DDA25A802128238B03857C5939C606399CED5B260293C2B190AE7BF3A92D1326DF68D4911DBCA95F02824B2E1C70B2E7D2A5FA0DFD8E0F21B4548DAFC22BE';
  i(17) := '3A10674B851527984953AA1F6C01FDEB7ED33E1D59AC6EA24B8173A5A082975F038507BA503607D4E4FAD6E092140149C83C88AFDAA85294A05294A05294A052958777B946B45B24DC26AF823C76CAD6473C0E83B93C80EE68350F153569B0DAC5BE03BC';
  i(18) := '3739A9212A49DD86F929CF7E89F5DFA550120FC9C29CA427F4E3E9C72A97BFDDE4DF2ED2AE737679F56423390DA07E940F403F2727AD43A905C74253939EDBD153167B8194DF03DF2BA9C8CE3F57B7AD4AFF000D7E4595FBA17984456E488BE5F998754B';
  i(19) := '201C84E318DF3B9E84F4AB4346787F0A1E915C1BB470A933807241070A688DD0127A14E739EE4F4AADF51D8DDD37777624A5A1C570F1B6E8C0E341C80A23A72208F7C6D8A827344F882AD36D356BBD87245BF931211BA981FB4A7994F6C72DC0C8C01724';
  i(20) := '394C4E8AD4A88EA1E61D485B6E20E4281EA2B951FB8625F98CA12AC0FA86C7D48AB07C2DD692ED2C26D52E3AE4C4528B8D96C7F319493F3AB840DD3939C6C79E33CAAA2F0A57869C43CDA5C69695A160292A49C8503C883DABDD0294A50294A502A9AF1A';
  i(21) := '7537C44C6F4F4458F2A390F4C20F35F3423EC3E63EA53DAACAD657E469BD3D2AE4A485B88012CB67EB715B247B6773E80D7324B79F9121D7E438A71F75656EAD5CD4A27249FB9A0FC52F35677849A3152A5A2F7716BF90C2B8994ABEB70723EC9E7FEEC7';
  i(22) := 'ED35AD787BA45FD4B754970291099214F383B761EA7FFB95744C58CCC48EDC78CDA5B69B484A109E400A0FAD69DADB4041D52EA257C4390E5A5210A75090B0B48E40A491B8CEC41FCED8DC6941CC8CE96B833A997654B28952DB7BCBF2D2ACA5C2372A51';
  i(23) := '1FA5183939DFA73ABBB49586169990F452C244996028C8E227CCC0DD033C80DC81FF0059397FC21367BDCCBD436CBBF19C3F14D0402A0075475CF529EBEE003273586AED6ECC77C0E24F1B1211BF02BE950EFBD061292BB0B8A71B495DAD64A96DA464C6';
  i(24) := '2772A48EA8EA47D3CC6D90269B5A5C4256DA8290A00A54939041EA2A2ED53E44982D7F106C4696DA0194927E549190483D8F0939E83D6B2AD51DA8D0D2861050D152968472090A513803A0DF974E541994A52814A52830EED6C877782E42B8309798739A';
  i(25) := '4F4239107A11DEAABBD784D304F6CDAA434F445AF07CF570ADA1F61850FC1F4A5282CDD3D658B61B5B5061A70840CA958C15ABA935274A50294A507E1008C1E551E2118921C7A338A432EE4B8D04F10E2FDC07427AF43CF9E495283CB514497788B3E547';
  i(26) := '18C85270B788E455D703B1DC9E7B7393A52814A5283FFFD9';
  l_blob := varchar2_to_blob(i);
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(7, 'Belt', 'Leather belt', 'Accessories', 'Y', 30, l_blob,'image/jpeg','belt.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 8
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB0084000906061412111514131415131316151B151716171814181512181A1815141B1C1E161A1C261E1819241914161F2F20232A292C2C2F171E3135302A35262B2C2901090A0A0E0C0E170F0F17';
  i(2)  := '2C1C1C1C2C2C342C292929292929292C2C2C2C2C2C2C29292929292929292C2C292C292929292C292C29292C2C292929292C35292C29FFC00011080068006803012200021101031101FFC4001C0000010501010100000000000000000000000304060708';
  i(3)  := '050201FFC40046100001030203040507060B09000000000001000203041105214106071231135161718122425291A1B1D114233293A2C11517435462637292B2D3F0162453647382A3C2D2FFC400160101010100000000000000000000000000000102FF';
  i(4)  := 'C400191101010100030000000000000000000000000111213141FFDA000C03010002110311003F00BC5789A60C6971E4D049EE02E57B4C31E9B8296777A30C8EF531C7EE4113A2DF561B21B748F60D1CE8DDC27C5B7B78D97521DE661AEE55910FDA25BF';
  i(5)  := 'C402CD94381C5281F49B90BD8DFDE14830BC368A21F3D46EAA1E936A658C91DAD02C7C08545F876F70FF00CF69BEB59F15F59B7340795653FD633E2A9E6E278735A4438231C7AE698BADE243DDEE509C7A0964771474915330694C5FEDE279B9F00A2B4D';
  i(6)  := '9DB2A2FCEA0FAC6FC528CDABA33CAAA0FAD8FE2B28C523864E9DCD3D52464FC57D329D2584FF00B2C7F855C46B11B454D7B7CA20BFFAB1FF00E97C7ED2D28C8D4C008D3A58EFEABACC786C14EF67CF4B58E7E8DA786011839FE51F25CE9E68F14DDDB2A6';
  i(7)  := '491C58E9238BCDE91C1EF03B4B4347A87AD06963B7F41D23221531BA491E23635A788B9CE3C20642DCCA902CC7B25B32D8710A325E5EFF009543C8587D369E67DCB4E05142108440B89B6D2F0E1D567FCB4BED8DC3EF5DB518DE6CFC184D59FD491FBC43';
  i(8)  := '7EF419DE9CBA2601C1F481B125A01B5AFAE5CC7AD23F87C8C88B5B4BA5057F14638B87C9BF55FD7D592468AAF879B1A7BC2AA5A3DA72340BD9DA4CCD80CF4CF2F6250BDA73E065FB8251D4CC78B88D808D2D9140D7FB400F300FB7DE1291E3510F31BEA1';
  i(9)  := '97B126E8870348863CC751CFDB9242091872E8197EBCFE283A916D3B75B04A3B69A2E77CD730D3869CE08DC3BDD7F7A467E0360210DF177C532096ECF4FD257D1DB3FEF515CD9E39383B50068B450599F09DB110D4529783D0C52B5C7845DFE4E595F99C';
  i(10) := 'FDAB4950D63658D9230DD8F687B4D88BB5C0381B1CC64543C2E8421102AC77CFB4AE6D2CB4CD85EE6BBA3E965360C602EE36B46772E3D19F515672A3F7D78D033BA9D84969E8BA5F45AF6F191E6E4EB39BCCF9DCB552AC560D8C3B88736DEE0256E2E99B';
  i(11) := '64B725EC3C95A0F2C4794DD74EA4AC789581EBB1F726AC9085F248C104806E02A3AD455CC735A350125554FAB466B90C8C8B1053B6E22F1CD40E63AA3A85E2595A73D5349B102ED2C5367D41B141D8D89A26546274B0CAD0F8DF210E69E4E1C2E247B15E';
  i(12) := '3B19B42E8AA64A09448F6B669194F396D9B270B448E61232E30093965D8059533BA8F2B19A3EC738FAA294AB77656432E335ADCCC74D248F06DE7CE218F2CF9010483BC958B39D6A75CAC64210B4C059837BE0B719AB00901DD1B8804D8FCCC5CC6BC8AD';
  i(13) := '3EB386FAA90B7187B88CA48A3703D766F07BD85042298129CC51A4A38C8E495634AD2968E1CF34EE3918D06FCB84F8260E04F5F82F0EA736E45076592C190245D7A73A1B5B22B8DF213E89F7AF0EA6B6847AD4C0F6AA9A3232365C7A88ED9258C2742937';
  i(14) := 'B0EAA8956E5A3BE334FDD29FF8645696E71DD2CB8A5569356900F586F1B87B250AA2DDD55982AA59B97434953203D44445ADFB4E03C55EDBA2D9F7D261913246F048F2E95E0F305C6C2FDBC0D6ACA266842100A0DBD5D82FC214E1F101F2986E63FD634E';
  i(15) := '6E8C9EDB022FA8ED2A7284198309ABA2638475B47302D3C2F7C7348D7B48C8DE176BD6010AD7C3374F85D444D9617CCF8DE2ED736677B88C88E441CC275BCEDDEB6B2333C2D1F2A60BD87E5DA3CD3D6F03E89F0E445A07BA9DAE34B58DA671F99A8706D8';
  i(16) := 'F9921C9AE034B9B34F78EA544DDFB8EA13C9F523BA469F7B0A4BF11547FE3557EF45FCB5642134571F88CA4D2A2AC773A1FE5A6357B8B1F92AD947648C6BC7D92D56AA14148546E2EAC5F867A77F789597FB2E5CAAADCD622DE51C527EC4ADFF00BF0AD0';
  i(17) := '8B9BB43B4115153BE799D663472F39EED1AD1AB89FEACAE8CEB0EC45532B22A49A3313AA0B5A47131C7A1E36979F21C6C2CC3CFD12B4DB459561BB085F5D53362738F2892C8FA9B95886F635966DF52E72B41281084280421080545EF6B64CD25632B211';
  i(18) := 'C31CAF0E36E51CC0F178715B887687762BD133C5F098EA617C32B7898F162351A820E841CC1409E038BB6AA9E399BC9ED048F45DC9C3C1D71E0BA0AB1C322A8C124735E1D3D03DD7E91A2E62D2EE68FA26D607CD361620E4AC7A2AE64CC6C91B9AF6385C';
  i(19) := '39A6E0FF005D4817422EA05B73BD982883A386D5153CB85A7C88CFE9B86BFA233EE4123DA9DADA7C3E132CEFB68D60CDF21EA6B75EFE435547B66ACDA5AE0338A9A33736B98E9D87D8F95D6CBAFB00C9CE0FBBCC43199FE535CF7C309F39C2CF7379F0C5';
  i(20) := '11FA2DED396B672BBF00D9F868E16C34EC0C8DBEB71D5CE773738F59452D846151D342C8626F0C71B785A35EF27524DC93D653C42110210840210840210841F085C49F63E024BA2E9299EECCBA9DEE8B88F5960F21C7B4B4A10819D5EC13651C32D65748';
  i(21) := 'D3CDA660D69EF0C636E97C1B602869487454ECE31C9EEBBDC3B8B89E1F0B2108242842100842100842107FFFD9';
  l_blob := varchar2_to_blob(i);
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(8, 'Bag', 'Unisex bag suitable for carrying laptops with room for many additional items', 'Accessories', 'Y', 125, l_blob,'image/jpeg','bag.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 9
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB004300090607080706090807080A0A090B0D160F0D0C0C0D1B14151016201D2222201D1F1F2428342C242631271F1F2D3D2D3135373A3A3A232B3F443F384334393A37FFDB0043010A0A0A0D0C0D';
  i(2)  := '1A0F0F1A37251F253737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737373737FFC00011080068006803012200021101031101FFC4001C00010001050101000000000000000000000007';
  i(3)  := '02030406080501FFC4003A100001030203060305050803000000000001000203041105213106071251617141819113142223A1324252B1C115173343445372D16284C2FFC40017010101010100000000000000000000000000010203FFC4001911010101';
  i(4)  := '01010100000000000000000000000102112212FFDA000C03010002110311003F009C5111011110111101111011110111101111079BB458C418060B5589D502E8E065C301B17B89B35A3A9240F3518D0EF271B967E29AA30E6B0E7EC8D23C37B077B4BF9D';
  i(5)  := 'BCBC16C5BE2783B38223A125DDCE83E8E77A28222A82D3C2F272D1CB1B9AE796F1F3DF4E82C33783452B47ED3A596972CE68499E2F568E21E6D03AADA30FC4E871288CB875653D5463574128781E85734D2E2660B7CE196963A7EAB22BB6864AC6362643';
  i(6)  := '097DACEA99226BA4B726B88B8EFAF2B6AB18DEEDE58DEF1893B2A64C6F797826175BEEB1B67ACE13F364A70D2D676248E2F2CBADF259DB1FB6987ED3B1D1C3F2AAD8389D0937BB6F939A7C469D42E7A7161177BDED63756B4DAFE7AAB13C3253BA39DD7F';
  i(7)  := '8802D68362D3E163A83D47D17671759A28D7775BC838DCEEA0C71D4904E1A3D948D2E6179D08707139F5BE7C82925A43802D2083A1083EA222022220222208E77D4C95F825198AF66CC4BADDB2FCCA82DF62E37162A7ADEBE314F4347052D652BE5A7973';
  i(8)  := '7C91E6E8B501D6E5716F0CC8B7230C5751C53B9D35048D9E1E6DC883C88D41EEA8F3006AAD8EE0D150F8DCC3620854B49BE6A0CA63F319E8AF0F660BE49AEEE21C0C00663A0EA561870009571B3BF87D9C4DBC8EE795875406D33DCD2F692DBEA49E2254';
  i(9)  := 'B7BA4DAEA99661826253C669D9186D2991C039A464182C05DB6D01CC5AD722D68CE96131C5C25DC4E39B9C42A656BA2904911731C0E446483A9D1441B13BCA9E00CA2C7499A219367FBEDEFCD4AF455B4D5D009A92664B19F169FCF920C844440444411D';
  i(10) := '6F66036A2A830BDCC0D7B0C8CD4136F848391BF2B8391D74511D4E1519799699E6391BABA2BB4B7BB7223E8174ECF0C55113A19E364B13C59CC7B4383875056A18C6EEB0BAD71928647D1C96B0681C71FA1CC79103A20829FEF31464D7402A606EB34560';
  i(11) := 'F60E67416EE00EAADC942D9A175450C8268DBF6AC2CE67F93750A6EC3B76F08A231E21516A86DC472528B11992092467DBC39AD136A761ABB01A9155070C763F2EAA16FCA7DFEEBDB9F0DF9660F271CC047D636B1D4ABF010C370003E36F155D5811CAF6';
  i(12) := 'D543EED35F8AD7BB08BE563CBC2F98EB7C95B65B40420F4A19B9155C8CF697239AC069234579B339A73CD052E0E8DF9123B2D8300DA29B0991AF8EA248EDF81C73F25E23A40F377B2EADBA4846B1DC77412F615BD3A41C2DC49B76FE368B1F4D3F25BE60';
  i(13) := 'F8C61F8D52FBCE19551D4457B1E139B4F223C0AE5D9AAE2D1B134755B66EBB1F6611B490B789DECAAC18A4634EB95DA6DCC11F53D50742A2B54D5115553C5514EF12432B03D8F1A39A45C1F44417511101512C51CD1BA3958D7C6F04398E170E1C8855A2';
  i(14) := '08DB6AF768DA90E9B057340B977BACCEC81E6C77879FA81928B716D96ACC2A42DADA49A94DF22F670B4F670F84F95D74DAF8E6B5ED2D70041D41D0A0E56F71A96FF0E5047FCAC7EB974F05F1D057DFF976BEB73FA02BA46AF64F00AB25D36134BC475732';
  i(15) := '3E027CDB65E7CBBBCD9A93FA3959D1B5327EAE515CF0E8AB2D673E368EAF3FE9597C329FB75110EC5C7FF2BA1BF767B317CE9AA0FF00DA7FFB5759BB7D936104E15C647F72A2575FC8BACA8E6E7C3133396779FF0018C347AB8FE8B67D95D8FC6F1B95A7';
  i(16) := '0DA092280E4EAA9EED601E3F111F176683D974061FB338161AE0EA1C1E86078D1ECA76F17ADAEBD641838161C308C1E8B0E12BA514B0B22123858BAC2D7B22CE444111101111011110111101111011110111101111011110111101111011110111101111';
  i(17) := '07FFD9';
  l_blob := varchar2_to_blob(i);  
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(9, 'Mens Shoes', 'Leather upper and lower lace up shoes', 'Mens', 'Y', 110, l_blob,'image/jpeg','shoes.jpg',systimestamp,null);
  -- Table: DEMO_PRODUCT_INFO - Product 10
  i := j;
  i(1)  := 'FFD8FFE000104A46494600010100000100010000FFDB008400090606100D111214110F101410111510120D0E180E101B101012161C15201412171E1C1F322A23252F1A1E152B3B202F33292E2E38211E31373C2E41262B2C2901090A0A0E0C0D1A0E0F1A';
  i(2)  := '29211F242E31293534352D352C2F2C2D342A2D2C29352D2E2C302C3435352F2C2D2C352C293534342C2C2E2A2C29292C2F2C342C2C2CFFC00011080068006803012200021101031101FFC4001B0001000203010100000000000000000000000607040508';
  i(3)  := '0302FFC4003C1000020102020606070509010000000000000102031104210506071251911322233161A141717281C1D1F0324252B2E1152433437392B1C2F114FFC4001A010100020301000000000000000000000000020301040506FFC4002911010002';
  i(4)  := '010203060700000000000000000001020304111221320531336181911334415171B1F0FFDA000C03010002110311003F00BC4000000000000000000000000000000000004635CF5DBF65285B0B52BCA6A527184E0B762B2BBBE6F3F424C8AE136F78497D';
  i(5)  := 'BC3568B5DF153A6E4BC1EF6E9B1DA953CE83B77A9A6F8DA54ECBCCADF1B80A75976908CBC5AEB2F5359AE7C0AAD7989D9D6D3E8EB97145FEAB5307B5BD1B55673AB0F6A8C9AE70B9B8C26BB68EADF631B42FC255141F2958E64D35808E16A4541CB7651D';
  i(6)  := 'E49BCD3BB4D5F9195A071B273DD94AF1B773E238E76DC8D1E2B5F839C4FBBAAE9D45249C5A69A4E2D34D34FB9A3E88BECDAA5F47D25F8655E36E0BA49B4B9344A0B22778DDCCC94E0BCD7ED3B000328000000000000209B505D5A0EFF8F2F7D2BBF87BCA';
  i(7)  := 'DE7F5F5F5F3B2B6A5FC3A197DE9F5BFB32E76E45677F2B1AD97BDE8FB3BC184635BD75A93F0A8BCE3F330F404BB55EA667EB8ACA8BF1AABCA9D8D668495AAC7DE663A519E5AAF58745ECAE5FB8FAAAD5F3DD7F126242B64F2BE0A5E15AA71FC34C9A9753';
  i(8)  := 'A61C7D5F8F7FCC80024D600000000000041F6A4BB2A19FDF92DDE39473E57E6562D967ED4EDD051CBF98F3F77773B157CDFEBE7F23572F53D2767781EA8E6B8BEA52F6E7F951A4D1157B58E68DDEB8BECE97B72FF069745DAF2BC77A495A0B849E4999AF';
  i(9)  := '4A9CBF35EDFA744EC7E57C1D5FEBC9F3A7449D95EEC572C1D64DB6E35DABF1EA53F916117D3A5CAD5F3CF69F300049AC000000000000846D6256C351E1D37FA4F32AD9CBF4E6CB935F3576AE90C3C6345C7A4A73E91464ECA6B7649C53F43CFD453B8FC0';
  i(10) := 'D5C34DC2B539539ACDC649ABAE2BD0D78ABA3572C4EFBBD0F66DEBF0B877E68D6B7E70A7EDCBF2FF00C35BA0E2B7F3BFA5ACFEBD04C70DA955F4D49D2A152942749749DA39A8CA2F753578C5B59F81E6F641A670D3BFFE58D48AFB4E9E2293CBD52717C9';
  i(11) := '12AC4CD1567BD69AAE7E4B2B62B513A1898E79568BE715F14CB1CAE3643A2B138578B8D7C3D5A4A5D04A1BF0B272ED54B778E5BB7F596396D3A5CDD64C4E7B4C7F720004DAA000000000000187A4F4450C5C372BD28D487A1359C5F18BEF4FC558CC0198';
  i(12) := '9989DE116D5AD44868DC4D4AB4AACA54EA53DC8D2947AD0774EFBCBBFBB85C9480622223B92BE4B649E2B4EF258006500000000000000000000000000000000000007FFFD9';
  l_blob := varchar2_to_blob(i);   
  INSERT INTO demo_product_info (product_id, product_name, product_description, category,product_avail, list_price, product_image, mimetype, filename, image_last_update, tags)
      VALUES(10, 'Wallet', 'Travel wallet suitable for men and women. Several compartments for credit cards, passports and cash', 'Accessories', 'Y', 50, l_blob,'image/jpeg','wallet.jpg',systimestamp,null);
  -- Table: DEMO_CUSTOMERS
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
   VALUES(1, 'John', 'Dulles', '45020 Aviation Drive', null, 'Sterling', 'VA', '20166', 'john.dulles@email.com', '703-555-2143', '703-555-8967', 'http://www.johndulles.com', 1000, null);
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
    VALUES(2, 'William', 'Hartsfield', '6000 North Terminal Parkway', null, 'Atlanta', 'GA', '30320', null, '404-555-3285', null, null, 1000, 'Repeat customer');
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
    VALUES(3, 'Edward', 'Logan', '1 Harborside Drive', null, 'East Boston', 'MA', '02128', null, '617-555-3295', null, null, 1000, 'Repeat customer');
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
    VALUES(4, 'Frank', 'OHare', '10000 West OHare', null, 'Chicago', 'IL', '60666', null, '773-555-7693', null, null, 1000, null);
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
    VALUES(5, 'Fiorello', 'LaGuardia', 'Hangar Center', 'Third Floor', 'Flushing', 'NY', '11371', null, '212-555-3923', null, null, 1000, null);
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
    VALUES(6, 'Albert', 'Lambert', '10701 Lambert International Blvd.', null, 'St. Louis', 'MO', '63145', null, '314-555-4022', null, null, 1000, null);
  INSERT INTO demo_customers (customer_id, cust_first_name, cust_last_name, cust_street_address1, cust_street_address2, cust_city, cust_state, cust_postal_code, cust_email, phone_number1, phone_number2, url, credit_limit, tags)
    VALUES(7, 'Eugene', 'Bradley', 'Schoephoester Road', null, 'Windsor Locks', 'CT', '06096', null, '860-555-1835', null, null, 1000, 'Repeat customer');
  -- Table: DEMO_ORDERS
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(1, 7,0, systimestamp-65,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(2, 1,0, systimestamp-51,'DEMO', 'Large Order');
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(3, 2,0, systimestamp-40,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(4, 5,0, systimestamp-38,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(5, 6,0, systimestamp-28,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(6, 3,0, systimestamp-23,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(7, 3,0, systimestamp-18,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(8, 4,0, systimestamp-10,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(9, 2,0, systimestamp-4,'DEMO', null);
  INSERT INTO demo_orders (order_id, customer_id, order_total, order_timestamp, user_name, tags) VALUES(10, 7,0, systimestamp-1,'DEMO', null);
  -- Table: DEMO_ORDER_ITEMS
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 1, 1, null, 10);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 1, 2, null, 8);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 1, 3, null, 5);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 1, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 2, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 3, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 4, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 5, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 6, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 7, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 8, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 9, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 2, 10, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 3, 4, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 3, 5, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 3, 6, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 3, 8, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 3, 10, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 4, 6, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 4, 7, null, 6);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 4, 8, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 4, 9, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 4, 10, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 5, 1, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 5, 2, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 5, 3, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 5, 4, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 5, 5, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 6, 3, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 6, 6, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 6, 8, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 6, 9, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 1, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 2, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 4, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 5, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 7, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 8, null, 1);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 7, 10, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 8, 2, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 8, 3, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 8, 6, null, 1);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 8, 9, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 9, 4, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 9, 5, null, 3);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 9, 8, null, 2);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 10, 1, null, 5);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 10, 2, null, 4);
  INSERT INTO demo_order_items (order_item_id, order_id, product_id, unit_price, quantity) VALUES(null, 10, 3, null, 2);
  -- Table: DEMO_STATES
  INSERT INTO demo_states (st, state_name) VALUES ('AK','ALASKA');
  INSERT INTO demo_states (st, state_name) VALUES ('AL','ALABAMA');
  INSERT INTO demo_states (st, state_name) VALUES ('AR','ARKANSAS');
  INSERT INTO demo_states (st, state_name) VALUES ('AZ','ARIZONA');
  INSERT INTO demo_states (st, state_name) VALUES ('CA','CALIFORNIA');
  INSERT INTO demo_states (st, state_name) VALUES ('CO','COLORADO');
  INSERT INTO demo_states (st, state_name) VALUES ('CT','CONNECTICUT');
  INSERT INTO demo_states (st, state_name) VALUES ('DC','DISTRICT OF COLUMBIA');
  INSERT INTO demo_states (st, state_name) VALUES ('DE','DELAWARE');
  INSERT INTO demo_states (st, state_name) VALUES ('FL','FLORIDA');
  INSERT INTO demo_states (st, state_name) VALUES ('GA','GEORGIA');
  INSERT INTO demo_states (st, state_name) VALUES ('HI','HAWAII');
  INSERT INTO demo_states (st, state_name) VALUES ('IA','IOWA');
  INSERT INTO demo_states (st, state_name) VALUES ('ID','IDAHO');
  INSERT INTO demo_states (st, state_name) VALUES ('IL','ILLINOIS');
  INSERT INTO demo_states (st, state_name) VALUES ('IN','INDIANA');
  INSERT INTO demo_states (st, state_name) VALUES ('KS','KANSAS');
  INSERT INTO demo_states (st, state_name) VALUES ('KY','KENTUCKY');
  INSERT INTO demo_states (st, state_name) VALUES ('LA','LOUISIANA');
  INSERT INTO demo_states (st, state_name) VALUES ('MA','MASSACHUSETTS');
  INSERT INTO demo_states (st, state_name) VALUES ('MD','MARYLAND');
  INSERT INTO demo_states (st, state_name) VALUES ('ME','MAINE');
  INSERT INTO demo_states (st, state_name) VALUES ('MI','MICHIGAN');
  INSERT INTO demo_states (st, state_name) VALUES ('MN','MINNESOTA');
  INSERT INTO demo_states (st, state_name) VALUES ('MO','MISSOURI');
  INSERT INTO demo_states (st, state_name) VALUES ('MS','MISSISSIPPI');
  INSERT INTO demo_states (st, state_name) VALUES ('MT','MONTANA');
  INSERT INTO demo_states (st, state_name) VALUES ('NC','NORTH CAROLINA');
  INSERT INTO demo_states (st, state_name) VALUES ('ND','NORTH DAKOTA');
  INSERT INTO demo_states (st, state_name) VALUES ('NE','NEBRASKA');
  INSERT INTO demo_states (st, state_name) VALUES ('NH','NEW HAMPSHIRE');
  INSERT INTO demo_states (st, state_name) VALUES ('NJ','NEW JERSEY');
  INSERT INTO demo_states (st, state_name) VALUES ('NM','NEW MEXICO');
  INSERT INTO demo_states (st, state_name) VALUES ('NV','NEVADA');
  INSERT INTO demo_states (st, state_name) VALUES ('NY','NEW YORK');
  INSERT INTO demo_states (st, state_name) VALUES ('OH','OHIO');
  INSERT INTO demo_states (st, state_name) VALUES ('OK','OKLAHOMA');
  INSERT INTO demo_states (st, state_name) VALUES ('OR','OREGON');
  INSERT INTO demo_states (st, state_name) VALUES ('PA','PENNSYLVANIA');
  INSERT INTO demo_states (st, state_name) VALUES ('RI','RHODE ISLAND');
  INSERT INTO demo_states (st, state_name) VALUES ('SC','SOUTH CAROLINA');
  INSERT INTO demo_states (st, state_name) VALUES ('SD','SOUTH DAKOTA');
  INSERT INTO demo_states (st, state_name) VALUES ('TN','TENNESSEE');
  INSERT INTO demo_states (st, state_name) VALUES ('TX','TEXAS');
  INSERT INTO demo_states (st, state_name) VALUES ('UT','UTAH');
  INSERT INTO demo_states (st, state_name) VALUES ('VA','VIRGINIA');
  INSERT INTO demo_states (st, state_name) VALUES ('VT','VERMONT');
  INSERT INTO demo_states (st, state_name) VALUES ('WA','WASHINGTON');
  INSERT INTO demo_states (st, state_name) VALUES ('WI','WISCONSIN');
  INSERT INTO demo_states (st, state_name) VALUES ('WV','WEST VIRGINIA');
  INSERT INTO demo_states (st, state_name) VALUES ('WY','WYOMING');
  -- Table: DEMO_CONSTRAINT_LOOKUP
  INSERT INTO demo_constraint_lookup (constraint_name, message) VALUES ('DEMO_CUST_CREDIT_LIMIT_MAX','Credit Limit must not exceed $5,000.');
  INSERT INTO demo_constraint_lookup (constraint_name, message) VALUES ('DEMO_CUSTOMERS_UK','Customer Name must be unique.');
  INSERT INTO demo_constraint_lookup (constraint_name, message) VALUES ('DEMO_PRODUCT_INFO_UK','Product Name must be unique.');
  INSERT INTO demo_constraint_lookup (constraint_name, message) VALUES ('DEMO_ORDER_ITEMS_UK','Product can only be entered once for each order.');
end insert_data;
end sample_data_pkg;
/

CREATE TABLE  "NPM_PROP_AGREE" 
   (  "AGREE_PROP_ID" NUMBER(*,0), 
  "AGREEMENT_ID" NUMBER(*,0), 
  "PROPERTY_ID" NUMBER(*,0)
   )
/

CREATE OR REPLACE FORCE VIEW  "NPM_LOG_UNIT" ("PROPERTY_ID", "PROPERTY_TYPE", "LEASE_TYPE", "LOG_UNIT_NAME", "PHY_UNIT_NAME", "PHY_ROOM_NAME", "START_DATE", "END_DATE", "BUILDING_ID", "FLOOR_ID", "PROPERTY_ID1", "AGREEMENT_ID") AS 
  SELECT 
    PROPERTY_ID,
    PROPERTY_TYPE,
    LEASE_TYPE,
    LOG_UNIT_NAME,
    PHY_UNIT_NAME,
    PHY_ROOM_NAME,
    START_DATE,
    END_DATE,
    BUILDING_ID,
    FLOOR_ID,
    PROPERTY_ID1,
    AGREEMENT_ID
FROM NPM_property where property_type = 'Logical Unit'
/
CREATE OR REPLACE FORCE VIEW  "NPM_PHY_ROOM" ("PROPERTY_ID", "PROPERTY_TYPE", "PHY_UNIT_NAME", "PHY_ROOM_NAME", "PRICE", "BUILDING_ID", "FLOOR_ID", "PROPERTY_ID1") AS 
  SELECT 
    PROPERTY_ID,
    PROPERTY_TYPE,
    PHY_UNIT_NAME,
    PHY_ROOM_NAME,
    PRICE,
    BUILDING_ID,
    FLOOR_ID,
    PROPERTY_ID1
FROM NPM_property where property_type = 'Physical Room'
/
CREATE OR REPLACE FORCE VIEW  "NPM_PHY_UNIT" ("PROPERTY_ID", "PROPERTY_TYPE", "PHY_UNIT_NAME", "BUILDING_ID", "FLOOR_ID", "PROPERTY_ID1") AS 
  SELECT 
    PROPERTY_ID,
    PROPERTY_TYPE,
    PHY_UNIT_NAME,
    BUILDING_ID,
    FLOOR_ID,
    PROPERTY_ID1
FROM NPM_property where property_type = 'Physical Unit'
/
CREATE TABLE  "NPM_CONTACT" 
   (    "CONTACT_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "TYPE" VARCHAR2(100) DEFAULT 'UT as Tenant', 
    "FIRST_NAME" VARCHAR2(100), 
    "LAST_NAME" VARCHAR2(100), 
    "STREET_ADDRESS" VARCHAR2(200), 
    "CITY" VARCHAR2(100), 
    "STATE" VARCHAR2(50), 
    "TITLE" VARCHAR2(50), 
    "PHONE" VARCHAR2(25), 
    "FAX" VARCHAR2(25), 
    "EMAIL" VARCHAR2(100), 
    "DEPARTMENT_ID" NUMBER(*,0), 
    "DELETED" CHAR(1), 
    "VENDOR_ID" NUMBER(*,0), 
    "REVIEWER" CHAR(10), 
    "SIGNATORY" CHAR(1), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CHECK ( type IN ('Contact', 'External Customer', 'UT as Landlord', 'UT as Tenant', 'Vendor', 'Vendor Landlord')) ENABLE, 
     CONSTRAINT "UTBC_CONTACT_PK" PRIMARY KEY ("CONTACT_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_CONTACT" ADD CONSTRAINT "RELATION_16" FOREIGN KEY ("DEPARTMENT_ID")
      REFERENCES  "NPM_DEPARTMENT" ("DEPARTMENT_ID") ENABLE
/
ALTER TABLE  "NPM_CONTACT" ADD CONSTRAINT "RELATION_38" FOREIGN KEY ("VENDOR_ID")
      REFERENCES  "NPM_VENDOR" ("VENDOR_ID") ENABLE
/
CREATE TABLE  "NPM_BUILDING" 
   (    "BUILDING_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "BUILDING_NAME" VARCHAR2(255), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "NPM_BUILDING_PK" PRIMARY KEY ("BUILDING_ID")
  USING INDEX  ENABLE
   )
/
CREATE TABLE  "NPM_AGREEMENTS" 
   (    "AGREEMENT_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "CONTRACT_NUMBER" NUMBER(*,0), 
    "PURPOSE" VARCHAR2(4000), 
    "START_DATE" DATE, 
    "END_DATE" DATE, 
    "SIGNED_DATE" DATE, 
    "CURRENT_AMOUNT" NUMBER(19,2), 
    "RECEIVED_DATE" DATE, 
    "RENEWABLE" CHAR(1), 
    "STATUS" VARCHAR2(100), 
    "SERVICE_TYPE" VARCHAR2(150), 
    "ACCOUNT_TYPE" NUMBER(2,0), 
    "LAST_CONTACT_DATE" DATE, 
    "LOGGED_BY" VARCHAR2(8), 
    "ORIGINAL_AMOUNT" NUMBER(19,2), 
    "DEPARTMENT_ID" NUMBER(*,0), 
    "VENDOR_ID" NUMBER(*,0), 
    "DEPT_CONTACT_ID" NUMBER(*,0), 
    "DEPT_CONTACT_ADMIN_ID" NUMBER(*,0), 
    "REVIEWED_BY" VARCHAR2(4000 CHAR), 
    "SIGNED_BY" VARCHAR2(4000 CHAR), 
    "ONGOING" CHAR(1), 
    "FOREIGN" CHAR(1), 
    "PARENT" NUMBER, 
    "VERSION" VARCHAR2(50), 
    "TYPE" VARCHAR2(40), 
    "FINAL" CHAR(1), 
    "NOTE" CLOB, 
    "VENDOR_CONTACT_ID" NUMBER(*,0), 
    "VEN_FORMER_NAME_ID" NUMBER, 
    "DEPT_FORMER_NAME_ID" NUMBER, 
    "DATE_ACCESSED" DATE, 
    "VERSION_PARENT" NUMBER(*,0), 
    "AGREEMENT_PARENT" NUMBER(*,0), 
    "DATE_ACCESSED_1" DATE, 
    "ALIAS" VARCHAR2(100), 
    "ASSIGNED_TO" VARCHAR2(100), 
    "AUTHOR" VARCHAR2(200), 
    "PROPERTY_ID" NUMBER(*,0), 
    "VERSION_DATE" DATE, 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_CONTRACT_ID_PK" PRIMARY KEY ("AGREEMENT_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "RELATION_30" FOREIGN KEY ("VENDOR_CONTACT_ID")
      REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "RELATION_34" FOREIGN KEY ("VEN_FORMER_NAME_ID")
      REFERENCES  "NPM_FORMER_NAME" ("NAME_ID") ENABLE
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "RELATION_35" FOREIGN KEY ("DEPT_FORMER_NAME_ID")
      REFERENCES  "NPM_FORMER_NAME" ("NAME_ID") ENABLE
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "UTBC_DEPARTMENT_CONTRACT" FOREIGN KEY ("DEPARTMENT_ID")
      REFERENCES  "NPM_DEPARTMENT" ("DEPARTMENT_ID") ENABLE
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "UTBC_DEPTCONTACT_CONTRACTV1" FOREIGN KEY ("DEPT_CONTACT_ADMIN_ID")
      REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "UTBC_DEPTCONTACT_CONTRACTV2" FOREIGN KEY ("DEPT_CONTACT_ID")
      REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
ALTER TABLE  "NPM_AGREEMENTS" ADD CONSTRAINT "UTBC_VENDOR_CONTRACT" FOREIGN KEY ("VENDOR_ID")
      REFERENCES  "NPM_VENDOR" ("VENDOR_ID") ENABLE
/
CREATE TABLE  "NPM_BORDATES" 
   (    "BORDATE_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "AGENDA_DUEDATE" DATE, 
    "MEETING_DATE" DATE, 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "NPM_BORDATES_PK" PRIMARY KEY ("BORDATE_ID")
  USING INDEX  ENABLE
   )
/
CREATE OR REPLACE FUNCTION  "SPLIT" (p_in_string VARCHAR2, p_delim VARCHAR2)
  RETURN t_array
IS
  i number :=0;
  pos number :=0;
  lv_str varchar2(50) := ltrim(p_in_string,p_delim);
  strings t_array := t_array();
BEGIN
 -- determine first chuck of string
 pos := instr(lv_str,p_delim,1,1);
 -- while there are chunks left, loop
 WHILE ( pos != 0)
 LOOP
 -- increment counter
   i := i + 1;
   -- create array element for chuck of string
   strings.extend;
   strings(i) := substr(lv_str,1,pos-1);
   -- remove chunk from string
   lv_str := substr(lv_str,pos+1,length(lv_str));
   -- determine next chunk
   pos := instr(lv_str,p_delim,1,1);
   -- no last chunk, add to array
   IF pos = 0
   THEN
     strings.extend;
     strings(i+1) := lv_str;
   END IF;
   END LOOP;
  -- return array
  RETURN strings;
END SPLIT;
/

CREATE OR REPLACE FUNCTION  "PARSE_MS_VALUELIST_TO_SQL" (p_delimited_str_list IN VARCHAR2
,p_value_delimiter IN VARCHAR2 DEFAULT ':')
RETURN value_list_tt pipelined
IS
l_ret_tab apex_application_global.vc_arr2;
BEGIN
l_ret_tab := apex_util.string_to_table(p_delimited_str_list, p_value_delimiter);
for i in 1..l_ret_tab.COUNT loop
PIPE ROW(value_list_to(l_ret_tab(i)));
end loop;
return;
END parse_ms_valuelist_to_sql;
/

CREATE OR REPLACE FUNCTION  "NO_HTML" 
      (p_string  IN CLOB)
      RETURN          CLOB
    AS
      v_string_in   CLOB := p_string;
      v_string_out  CLOB;
      v_temp  NUMERIC;
    BEGIN
      v_string_in := REPLACE(v_string_in, '</p>', '  ');
      v_string_in := REPLACE(v_string_in, '<br>', '  ');
      v_string_in := REPLACE(v_string_in, '<br/>', '  ');
      v_string_in := REPLACE(v_string_in, '<br />', '  ');
      WHILE INSTR (v_string_in, '>') > 0 LOOP
          v_temp := INSTR (v_string_in, '<');
          IF v_temp > 1 then
          v_string_out := v_string_out
                   || SUBSTR (v_string_in, 1, v_temp - 1);
          END IF;
          v_string_in  := SUBSTR (v_string_in, INSTR (v_string_in, '>') + 1);
     END LOOP;
     v_string_out := v_string_out || v_string_in;
      v_string_out := REPLACE(v_string_out, '&nbsp;', ' ');
      v_string_out := REPLACE(v_string_out, '&#39;', chr(39));
      v_string_out := REPLACE(v_string_out, '&quot;', '"');
      v_string_out := REPLACE(v_string_out, '&lt;', '<');
      v_string_out := REPLACE(v_string_out, '&gt;', '>');
      v_string_out := REPLACE(v_string_out, '&amp;', '&');
      v_string_out := REPLACE(v_string_out, chr(10), '');
      v_string_out := REPLACE(v_string_out, chr(13), '');
      v_string_out := REPLACE(v_string_out, chr(13), '');
     RETURN v_string_out;
   END no_html;
/

CREATE OR REPLACE FUNCTION  "GET_VEND_ID" 
(
  vend_name_var   VARCHAR2
)
RETURN NUMBER
AS
  vend_id_var   NUMBER;
BEGIN
  SELECT vendor_id
  into vend_id_var
  FROM NPM_vendor
  WHERE name = vend_name_var;
  
  return vend_id_var;
  
EXCEPTION 
  WHEN NO_DATA_FOUND THEN
  RETURN 0;
END;
/

CREATE OR REPLACE FUNCTION  "GET_DEPT_ID" 
(
  dept_name_var   VARCHAR2
)
RETURN NUMBER
AS
  dept_id_var   NUMBER;
BEGIN
  SELECT department_id
  into dept_id_var
  FROM NPM_department
  WHERE name = dept_name_var;
  
  return dept_id_var;
  
EXCEPTION 
  WHEN NO_DATA_FOUND THEN
  RETURN 0;
END;
/
CREATE INDEX  "AGREEMENT_ID_FK_20" ON  "NPM_DOCUMENT" ("AGREEMENT_ID")
/
CREATE INDEX  "AGREEMENT_ID_FK_26" ON  "NPM_TICKLERS" ("AGREEMENT_ID")
/
CREATE INDEX  "AGREEMENT_ID_FK_28" ON  "NPM_PROP_AGREE" ("AGREEMENT_ID")
/
CREATE INDEX  "AGREEMENT_ID_FK_3" ON  "NPM_EMAIL" ("AGREEMENT_ID")
/
CREATE INDEX  "AGREEMENT_ID_FK_7" ON  "NPM_AGREE_TRIG" ("AGREEMENT_ID")
/
CREATE INDEX  "AGREEMENT_ID_FK_9" ON  "NPM_AGREE_APP" ("AGREEMENT_ID")
/
CREATE INDEX  "AGREE_APP_ID_FK_17" ON  "NPM_TICKLERS" ("AGREE_APP_ID")
/
CREATE INDEX  "APEX$_ACL_IDX1" ON  "APEX$_ACL" ("WS_APP_ID")
/
CREATE UNIQUE INDEX  "APEX$_ACL_PK" ON  "APEX$_ACL" ("ID")
/
CREATE INDEX  "APEX$_WS_FILES_IDX1" ON  "APEX$_WS_FILES" ("WS_APP_ID", "DATA_GRID_ID", "ROW_ID")
/
CREATE INDEX  "APEX$_WS_FILES_IDX2" ON  "APEX$_WS_FILES" ("WS_APP_ID", "WEBPAGE_ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_FILES_PK" ON  "APEX$_WS_FILES" ("ID")
/
CREATE INDEX  "APEX$_WS_HISTORY_IDX" ON  "APEX$_WS_HISTORY" ("WS_APP_ID", "DATA_GRID_ID", "ROW_ID")
/
CREATE INDEX  "APEX$_WS_LINKS_IDX1" ON  "APEX$_WS_LINKS" ("WS_APP_ID", "DATA_GRID_ID", "ROW_ID")
/
CREATE INDEX  "APEX$_WS_LINKS_IDX2" ON  "APEX$_WS_LINKS" ("WS_APP_ID", "WEBPAGE_ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_LINKS_PK" ON  "APEX$_WS_LINKS" ("ID")
/
CREATE INDEX  "APEX$_WS_NOTES_IDX1" ON  "APEX$_WS_NOTES" ("WS_APP_ID", "DATA_GRID_ID", "ROW_ID")
/
CREATE INDEX  "APEX$_WS_NOTES_IDX2" ON  "APEX$_WS_NOTES" ("WS_APP_ID", "WEBPAGE_ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_NOTES_PK" ON  "APEX$_WS_NOTES" ("ID")
/
CREATE INDEX  "APEX$_WS_ROWS_IDX" ON  "APEX$_WS_ROWS" ("WS_APP_ID", "DATA_GRID_ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_ROWS_PK" ON  "APEX$_WS_ROWS" ("ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_ROWS_UK1" ON  "APEX$_WS_ROWS" ("WS_APP_ID", "DATA_GRID_ID", "UNIQUE_VALUE")
/
CREATE INDEX  "APEX$_WS_TAGS_IDX1" ON  "APEX$_WS_TAGS" ("WS_APP_ID", "DATA_GRID_ID", "ROW_ID")
/
CREATE INDEX  "APEX$_WS_TAGS_IDX2" ON  "APEX$_WS_TAGS" ("WS_APP_ID", "WEBPAGE_ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_TAGS_PK" ON  "APEX$_WS_TAGS" ("ID")
/
CREATE INDEX  "APEX$_WS_WEBPG_SECHIST_IDX1" ON  "APEX$_WS_WEBPG_SECTION_HISTORY" ("WS_APP_ID", "WEBPAGE_ID", "SECTION_ID")
/
CREATE UNIQUE INDEX  "APEX$_WS_WEBPG_SECTIONS_PK" ON  "APEX$_WS_WEBPG_SECTIONS" ("ID")
/
CREATE INDEX  "APPROVAL_ID_FK_12" ON  "NPM_AGREE_APP" ("APPROVAL_ID")
/
CREATE INDEX  "BUILDING_ID_FK_31" ON  "NPM_FLOOR" ("BUILDING_ID")
/
CREATE INDEX  "BUILDING_ID_FK_32" ON  "NPM_PROPERTY" ("BUILDING_ID")
/
CREATE INDEX  "CONTACT_ID_FK_19" ON  "NPM_TICKLERS" ("CONTACT_ID")
/
CREATE INDEX  "CURRENT_NAME_ID_FK_15" ON  "NPM_DEPARTMENT" ("CURRENT_NAME_ID")
/
CREATE INDEX  "CURRENT_NAME_ID_FK_35" ON  "NPM_VENDOR" ("CURRENT_NAME_ID")
/
CREATE UNIQUE INDEX  "DEMO_CUSTOMERS_PK" ON  "DEMO_CUSTOMERS" ("CUSTOMER_ID")
/
CREATE UNIQUE INDEX  "DEMO_CUSTOMERS_UK" ON  "DEMO_CUSTOMERS" ("CUST_FIRST_NAME", "CUST_LAST_NAME")
/
CREATE INDEX  "DEMO_CUST_NAME_IX" ON  "DEMO_CUSTOMERS" ("CUST_LAST_NAME", "CUST_FIRST_NAME")
/
CREATE UNIQUE INDEX  "DEMO_ORDER_ITEMS_PK" ON  "DEMO_ORDER_ITEMS" ("ORDER_ITEM_ID")
/
CREATE UNIQUE INDEX  "DEMO_ORDER_ITEMS_UK" ON  "DEMO_ORDER_ITEMS" ("ORDER_ID", "PRODUCT_ID")
/
CREATE UNIQUE INDEX  "DEMO_ORDER_PK" ON  "DEMO_ORDERS" ("ORDER_ID")
/
CREATE INDEX  "DEMO_ORD_CUSTOMER_IX" ON  "DEMO_ORDERS" ("CUSTOMER_ID")
/
CREATE UNIQUE INDEX  "DEMO_PRODUCT_INFO_PK" ON  "DEMO_PRODUCT_INFO" ("PRODUCT_ID")
/
CREATE UNIQUE INDEX  "DEMO_PRODUCT_INFO_UK" ON  "DEMO_PRODUCT_INFO" ("PRODUCT_NAME")
/
CREATE UNIQUE INDEX  "DEMO_TAGS_SUM_PK" ON  "DEMO_TAGS_SUM" ("TAG")
/
CREATE UNIQUE INDEX  "DEMO_TAGS_TYPE_SUM_PK" ON  "DEMO_TAGS_TYPE_SUM" ("TAG", "CONTENT_TYPE")
/
CREATE INDEX  "DEPARTMENT_ID_FK_2" ON  "NPM_CONTACT" ("DEPARTMENT_ID")
/
CREATE INDEX  "DEPARTMENT_ID_FK_21" ON  "NPM_AGREEMENTS" ("DEPARTMENT_ID")
/
CREATE INDEX  "DEPARTMENT_ID_FK_22" ON  "NPM_TICKLERS" ("DEPARTMENT_ID")
/
CREATE INDEX  "DEPARTMENT_ID_FK_5" ON  "NPM_FORMER_NAME" ("DEPARTMENT_ID")
/
CREATE INDEX  "DEPT_CONTACT_ADMIN_ID_FK_23" ON  "NPM_AGREEMENTS" ("DEPT_CONTACT_ADMIN_ID")
/
CREATE INDEX  "DEPT_CONTACT_ID_FK_24" ON  "NPM_AGREEMENTS" ("DEPT_CONTACT_ID")
/
CREATE INDEX  "DEPT_FORMER_NAME_ID_FK_14" ON  "NPM_AGREEMENTS" ("DEPT_FORMER_NAME_ID")
/
CREATE INDEX  "EMAIL_ID_FK_25" ON  "NPM_DOCUMENT" ("EMAIL_ID")
/
CREATE INDEX  "FLOOR_ID_FK_33" ON  "NPM_PROPERTY" ("FLOOR_ID")
/
CREATE UNIQUE INDEX  "NPM_AGREEMENTS__IDX" ON  "NPM_AGREEMENTS" ("PROPERTY_ID")
/
CREATE UNIQUE INDEX  "NPM_BORDATES_PK" ON  "NPM_BORDATES" ("BORDATE_ID")
/
CREATE UNIQUE INDEX  "NPM_BUILDING_PK" ON  "NPM_BUILDING" ("BUILDING_ID")
/
CREATE UNIQUE INDEX  "NPM_FLOOR_PK" ON  "NPM_FLOOR" ("FLOOR_ID")
/
CREATE UNIQUE INDEX  "NPM_PROPERTY__IDX" ON  "NPM_PROPERTY" ("AGREEMENT_ID")
/
CREATE UNIQUE INDEX  "NPM_STATE_PK" ON  "NPM_STATE" ("STATE_ID")
/
CREATE INDEX  "PROGRAMATIC_APPROVER_FK_10" ON  "NPM_DEPARTMENT" ("PROGRAMATIC_APPROVER")
/
CREATE INDEX  "PROPERTY_ID1_FK_34" ON  "NPM_PROPERTY" ("PROPERTY_ID1")
/
CREATE INDEX  "PROPERTY_ID_FK_29" ON  "NPM_PROP_AGREE" ("PROPERTY_ID")
/
CREATE INDEX  "RECEIVER_ID_FK_8" ON  "NPM_EMAIL" ("RECEIVER_ID")
/
CREATE INDEX  "SENDER_ID_FK_18" ON  "NPM_EMAIL" ("SENDER_ID")
/
CREATE UNIQUE INDEX  "SYS_C0032394881" ON  "DEPT" ("DEPTNO")
/
CREATE UNIQUE INDEX  "SYS_C0032394883" ON  "EMP" ("EMPNO")
/
CREATE UNIQUE INDEX  "SYS_C0032394888" ON  "DEMO_TAGS" ("ID")
/
CREATE UNIQUE INDEX  "SYS_C0032394915" ON  "DEMO_CONSTRAINT_LOOKUP" ("CONSTRAINT_NAME")
/
CREATE UNIQUE INDEX  "SYS_C0032394984" ON  "APEX$TEAM_DEV_FILES" ("ID")
/
CREATE INDEX  "TRIGGER_ID_FK_6" ON  "NPM_AGREE_TRIG" ("TRIGGER_ID")
/
CREATE UNIQUE INDEX  "UTBC_AGREE_APP_PK" ON  "NPM_AGREE_APP" ("AGREE_APP_ID")
/
CREATE UNIQUE INDEX  "UTBC_AGREE_TRIG_PK" ON  "NPM_AGREE_TRIG" ("AGREE_TRIG_ID")
/
CREATE UNIQUE INDEX  "UTBC_APPROVALS_PK" ON  "NPM_APPROVALS" ("APPROVAL_ID")
/
CREATE UNIQUE INDEX  "UTBC_CONTACT_PK" ON  "NPM_CONTACT" ("CONTACT_ID")
/
CREATE UNIQUE INDEX  "UTBC_CONTRACT_ID_PK" ON  "NPM_AGREEMENTS" ("AGREEMENT_ID")
/
CREATE UNIQUE INDEX  "UTBC_CORRESPONDANCE_PK" ON  "NPM_EMAIL" ("EMAIL_ID")
/
CREATE UNIQUE INDEX  "UTBC_DEPARTMENT_PK" ON  "NPM_DEPARTMENT" ("DEPARTMENT_ID")
/
CREATE UNIQUE INDEX  "UTBC_DOCUMENT_PK" ON  "NPM_DOCUMENT" ("DOCUMENT_ID")
/
CREATE UNIQUE INDEX  "UTBC_FORMER_NAME_PK" ON  "NPM_FORMER_NAME" ("NAME_ID")
/
CREATE UNIQUE INDEX  "UTBC_PROPERTY_PK" ON  "NPM_PROPERTY" ("PROPERTY_ID")
/
CREATE UNIQUE INDEX  "UTBC_TICKLERS_PK" ON  "NPM_TICKLERS" ("TICKLER_ID")
/
CREATE UNIQUE INDEX  "UTBC_TRIGGERS_PK" ON  "NPM_TRIGGERS" ("TRIGGER_ID")
/
CREATE UNIQUE INDEX  "UTBC_VENDOR_PK" ON  "NPM_VENDOR" ("VENDOR_ID")
/
CREATE INDEX  "VENDOR_CONTACT_ID_FK_11" ON  "NPM_AGREEMENTS" ("VENDOR_CONTACT_ID")
/
CREATE INDEX  "VENDOR_ID_FK_16" ON  "NPM_CONTACT" ("VENDOR_ID")
/
CREATE INDEX  "VENDOR_ID_FK_27" ON  "NPM_AGREEMENTS" ("VENDOR_ID")
/
CREATE INDEX  "VENDOR_ID_FK_28" ON  "NPM_TICKLERS" ("VENDOR_ID")
/
CREATE INDEX  "VENDOR_ID_FK_4" ON  "NPM_FORMER_NAME" ("VENDOR_ID")
/
CREATE INDEX  "VEN_FORMER_NAME_ID_FK_13" ON  "NPM_AGREEMENTS" ("VEN_FORMER_NAME_ID")
/
CREATE TABLE  "NPM_AGREE_APP" 
   (    "AGREE_APP_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "PARENT" NUMBER(*,0), 
    "COMPLETE" CHAR(1), 
    "AGREEMENT_ID" NUMBER(*,0), 
    "APPROVAL_ID" NUMBER(*,0), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_AGREE_APP_PK" PRIMARY KEY ("AGREE_APP_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_AGREE_APP" ADD CONSTRAINT "RELATION_28" FOREIGN KEY ("AGREEMENT_ID")
      REFERENCES  "NPM_AGREEMENTS" ("AGREEMENT_ID") ENABLE
/
ALTER TABLE  "NPM_AGREE_APP" ADD CONSTRAINT "RELATION_32" FOREIGN KEY ("APPROVAL_ID")
      REFERENCES  "NPM_APPROVALS" ("APPROVAL_ID") ENABLE
/
CREATE TABLE  "NPM_AGREE_TRIG" 
   (    "AGREE_TRIG_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "TRIGGER_ID" NUMBER(*,0), 
    "AGREEMENT_ID" NUMBER(*,0), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_AGREE_TRIG_PK" PRIMARY KEY ("AGREE_TRIG_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_AGREE_TRIG" ADD CONSTRAINT "RELATION_25" FOREIGN KEY ("TRIGGER_ID")
      REFERENCES  "NPM_TRIGGERS" ("TRIGGER_ID") ENABLE
/
ALTER TABLE  "NPM_AGREE_TRIG" ADD CONSTRAINT "RELATION_26" FOREIGN KEY ("AGREEMENT_ID")
      REFERENCES  "NPM_AGREEMENTS" ("AGREEMENT_ID") ENABLE
/
CREATE TABLE  "NPM_APPROVALS" 
   (    "APPROVAL_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "NAME" VARCHAR2(50 CHAR), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_APPROVALS_PK" PRIMARY KEY ("APPROVAL_ID")
  USING INDEX  ENABLE
   )
/
CREATE TABLE  "NPM_DEPARTMENT" 
   (    "DEPARTMENT_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "PROGRAMATIC_APPROVER" NUMBER(*,0), 
    "CURRENT_NAME_ID" NUMBER, 
    "NAME" VARCHAR2(255), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_DEPARTMENT_PK" PRIMARY KEY ("DEPARTMENT_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_DEPARTMENT" ADD CONSTRAINT "RELATION_29" FOREIGN KEY ("PROGRAMATIC_APPROVER")
      REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
ALTER TABLE  "NPM_DEPARTMENT" ADD CONSTRAINT "RELATION_37" FOREIGN KEY ("CURRENT_NAME_ID")
      REFERENCES  "NPM_FORMER_NAME" ("NAME_ID") ENABLE
/
CREATE TABLE  "NPM_DOCUMENT" 
   (    "DOCUMENT_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "FILENAME" VARCHAR2(4000), 
    "FILE_MIMETYPE" VARCHAR2(512), 
    "FILE_CHARSET" VARCHAR2(512), 
    "FILE_DATA" BLOB, 
    "FILE_COMMENTS" VARCHAR2(4000), 
    "TAGS" VARCHAR2(4000), 
    "EMAIL_ID" NUMBER(*,0), 
    "AGREEMENT_ID" NUMBER(*,0), 
    "FILE_SIZE" NUMBER(*,0), 
    "AGREE_APP_ID" NUMBER(*,0), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_DOCUMENT_PK" PRIMARY KEY ("DOCUMENT_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_DOCUMENT" ADD CONSTRAINT "UTBC_CONTRACT_DOCUMENT" FOREIGN KEY ("AGREEMENT_ID")
      REFERENCES  "NPM_AGREEMENTS" ("AGREEMENT_ID") ENABLE
/
ALTER TABLE  "NPM_DOCUMENT" ADD CONSTRAINT "UTBC_DOCUMENT_TALK" FOREIGN KEY ("EMAIL_ID")
      REFERENCES  "NPM_EMAIL" ("EMAIL_ID") ENABLE
/
CREATE TABLE  "NPM_EMAIL" 
   (    "EMAIL_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "date" DATE, 
    "SENDER_ID" NUMBER(*,0), 
    "RECEIVER_ID" NUMBER(*,0), 
    "SENDER_EMAIL" VARCHAR2(256), 
    "RECIPIENT_EMAIL" VARCHAR2(256), 
    "EMAIL_BODY" CLOB, 
    "AGREEMENT_ID" NUMBER(*,0), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_CORRESPONDANCE_PK" PRIMARY KEY ("EMAIL_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_EMAIL" ADD CONSTRAINT "RELATION_20" FOREIGN KEY ("AGREEMENT_ID")
      REFERENCES  "NPM_AGREEMENTS" ("AGREEMENT_ID") ENABLE
/
ALTER TABLE  "NPM_EMAIL" ADD CONSTRAINT "RELATION_27" FOREIGN KEY ("RECEIVER_ID")
      REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
ALTER TABLE  "NPM_EMAIL" ADD CONSTRAINT "UTBC_CONTACT_TALK" FOREIGN KEY ("SENDER_ID")
      REFERENCES  "NPM_CONTACT" ("CONTACT_ID") ENABLE
/
CREATE TABLE  "NPM_FLOOR" 
   (    "FLOOR_ID" NUMBER(*,0) NOT NULL ENABLE, 
    "FLOOR_NAME" VARCHAR2(255), 
    "BUILDING_ID" NUMBER(*,0), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "NPM_FLOOR_PK" PRIMARY KEY ("FLOOR_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_FLOOR" ADD CONSTRAINT "B_TO_F_RELATION" FOREIGN KEY ("BUILDING_ID")
      REFERENCES  "NPM_BUILDING" ("BUILDING_ID") ENABLE
/
CREATE TABLE  "NPM_FORMER_NAME" 
   (    "NAME_ID" NUMBER NOT NULL ENABLE, 
    "VENDOR_ID" NUMBER(*,0), 
    "DEPARTMENT_ID" NUMBER(*,0), 
    "NAME" VARCHAR2(255), 
    "CURRENT_NAME" VARCHAR2(255), 
    "CREATED" DATE, 
    "CREATED_BY" VARCHAR2(255), 
    "ROW_VERSION_NUMBER" NUMBER(*,0), 
    "UPDATED" DATE, 
    "UPDATED_BY" VARCHAR2(255), 
     CONSTRAINT "UTBC_FORMER_NAME_PK" PRIMARY KEY ("NAME_ID")
  USING INDEX  ENABLE
   )
/
ALTER TABLE  "NPM_FORMER_NAME" ADD CONSTRAINT "RELATION_21" FOREIGN KEY ("VENDOR_ID")
      REFERENCES  "NPM_VENDOR" ("VENDOR_ID") ENABLE
/
ALTER TABLE  "NPM_FORMER_NAME" ADD CONSTRAINT "RELATION_22" FOREIGN KEY ("DEPARTMENT_ID")
      REFERENCES  "NPM_DEPARTMENT" ("DEPARTMENT_ID") ENABLE
/