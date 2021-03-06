
%% Clear For Fresh Run. ! Delete Section Before Submission !

clear
clc
%% Load Data

load ('TestTrack.mat');

bl = TestTrack.bl;       % Left Boundaries
br = TestTrack.br;       % Right Boundaries
cline = TestTrack.cline; % Center Line
theta = TestTrack.theta; % Center Line's Orientation

load('Y0.mat');

trajec = Y0';
theta_traject = trajec(5,:);
trajec = trajec([1,3],:);

plot(bl(1,:),bl(2,:),'r')
hold on
plot(br(1,:),br(2,:),'r')
hold on
plot(trajec(1,:),trajec(2,:),'x')
%% Initialize Constants

m    = 1400;                % Mass of Car
N_w  = 2.00;                % ?? 
f    = 0.01;                % ??
I_z  = 2667;                % Momemnt of Inertia
a    = 1.35;                % Front Axle to COM
b    = 1.45;                % Rear Axle to Com
B_y  = 0.27;                % Empirically Fit Coefficient
C_y  = 1.35;                % Empirically Fit Coefficient
D_y  = 0.70;                % Empirically Fit Coefficient
E_y  = -1.6;                % Empirically Fit Coefficient
S_hy = 0.00;                % Horizontal Offset in y
S_vy = 0.00;                % Vertical Offset in y
g    = 9.806;               % Graviational Constant

%% Initialize Time and Prediction Data

dt   = 0.01;                % Time Step
PredHorizon = 10;           % Prediction Horizon Size

interp_size = 100;
bl = [interp(bl(1,:),interp_size);interp(bl(2,:),interp_size)];
br = [interp(br(1,:),interp_size);interp(br(2,:),interp_size)];
cline = [interp(cline(1,:),interp_size);interp(cline(2,:),interp_size)];
trajec = [interp(trajec(1,:),interp_size);interp(trajec(2,:),interp_size)];
theta_traject = interp(theta_traject,interp_size);
theta = interp(theta,interp_size);
% cline = [interp(cline(1,:),interp_size);interp(cline(2,:),interp_size)];

hold on
plot(bl(1,:),bl(2,:),'g')
hold on
plot(br(1,:),br(2,:),'g')
hold on
plot(trajec(1,:),trajec(2,:),'b')

% nsteps = size(bl,2);
% T = 0.0:dt:nsteps*dt;

% nsteps  = size(bl,2);
nstates = 6;
ninputs = 2;


%% Initial Conditions

x0   =   287;
u0   =   5.0;
y0   =  -176;
v0   =   0.0;
psi0 =   2.0;
% psi0 =   theta(1);
r0   =   0.0;

z0 = [x0, u0, y0, v0, psi0, r0];

%% Nonlinear System Formulation

j = 0;
% Uin(:,i) = [Fx, deltaf]

alpha_f = @(Y)(U_in(2, j+1) - atan((Y(4)+a*Y(6))/Y(2)));
alpha_r = @(Y)(- atan((Y(4)-b*Y(6))/Y(2)));

psi_yf = @(Y)((1-E_y)*alpha_f(Y) + E_y/B_y*atan(B_y*alpha_f(Y)));  % S_hy = 0
psi_yr = @(Y)((1-E_y)*alpha_r(Y) + E_y/B_y*atan(B_y*alpha_r(Y)));  % S_hy = 0

F_yf = @(Y)(b/(a+b)*m*g*D_y*sin(C_y*atan(B_y*psi_yf(Y)))); %S_vy = 0;
F_yr = @(Y)(a/(a+b)*m*g*D_y*sin(C_y*atan(B_y*psi_yr(Y)))); %S_vy = 0;

sysNL = @(i,Y)[          Y(2)*cos(Y(5))-Y(4)*sin(Y(5));
               1/m*(-f*m*g+N_w*Uin(1,j+1)-F_yf(Y)*sin(Uin(2,j+1)))+Y(4)*Y(6);
                         Y(2)*sin(Y(5))+Y(4)*cos(Y(5));
                    1/m*(F_yf(Y)*cos(Uin(2,j+1))+F_yr)-Y(2)*Y(6);
                                        Y(6);
                          1/I_z*(a*F_yf(Y)*cos(Uin(2,j+1))-b*F_yr)];
%% PATH SEGMENT SELECTION
%9*interp

nsteps = 900;
bl = bl(:,1:nsteps);
br = br(:,1:nsteps);
cline = cline(:,1:nsteps);
theta = theta(:,1:nsteps) ;%,theta_traject(:, 20:nsteps)]
trajec = trajec(:,1:nsteps);
                      
%% REF PATH GENERATION

lowbounds = min(bl,br);
highbounds = max(bl,br);

[lb,ub]=bound_cons(nsteps,theta ,lowbounds, highbounds);


options = optimoptions('fmincon','SpecifyConstraintGradient',true,...
                       'SpecifyObjectiveGradient',true) ;
                   
% x0=zeros(1,5*nsteps-2); ?? 
endpoint = [245.3695, -56.4002];
xrefs = x0:(endpoint(1)-x0)/(nsteps-1):endpoint(1);
yrefs = y0:(endpoint(2)-y0)/(nsteps-1):endpoint(2);

states0 = [xrefs;u0*ones(1,nsteps);yrefs;v0*ones(1,nsteps);theta;r0*ones(1,nsteps)];
% states0(1:6:6*50) = x0;
% states0(3:6:6*50+2) = y0;
states0 = reshape(states0,1,nsteps*nstates);
X0 = [states0, repmat([1000.0,0.0],1,nsteps-1)];

% cf=@costfun;
cf=@costfun_segmt;
nc=@nonlcon;

z=fmincon(cf,X0,[],[],[],[],lb',ub',nc,options);

Y0=reshape(z(1:6*nsteps),6,nsteps)';
U=reshape(z(6*nsteps+1:end),2,nsteps-1);


plot(bl(1,:),bl(2,:),'g')
hold on
plot(br(1,:),br(2,:),'g')
hold on
plot(Y0(:,1),Y0(:,3),'b')

%% REF PATH FOLLOWING WITHOUT OBSTACLES

%% Functions Imported from HW

function [lb,ub]=bound_cons(nsteps,theta ,lowbounds, highbounds) %,input_range

% ub = zeros(1,6*nsteps);
% lb = zeros(1,6*nsteps);
% 
% for i = 1:nsteps
%     
% ub(6*i-5:6*i) = [highbounds(1,i), +inf,highbounds(2,i), +inf, theta(i)+pi/2, +inf];
% 
% lb(6*i-5:6*i) = [lowbounds(1,i), -inf, lowbounds(2,i), -inf, theta(i)-pi/2, -inf];
% 
% end

ub = [];
lb = [];

for i = 1:nsteps
    
ub = [ub,[highbounds(1,i), +inf,highbounds(2,i), +inf, theta(i)+pi/3, +inf]];

lb = [lb,[lowbounds(1,i), -inf, lowbounds(2,i), -inf, theta(i)-pi/3, -inf]];

end

% size(ub)
% size(lb)

ub = [ub,repmat([2500,0.5],1,nsteps-1) ]';
lb = [lb,repmat([-5000,-0.5],1,nsteps-1) ]';

end